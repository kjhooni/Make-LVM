#!/bin/bash

#스크립트 개선 필요사항 및 이슈사항 문의 > kimjh@didim365.com

function total(){
while true; do
    echo -e "\e[32m=============================================================\e[0m"
    echo -e "\e[32m                     fdisk -l                      \e[0m"
    echo -e "\e[32m=============================================================\e[0m"
    fdisk -l
    sleep 2

    while true; do
        echo -e "\e[32m입력할 디스크의 개수를 입력하세요: \e[0m"
        echo -e "\e[32m(1개의 디스크 LVM 설정 시 1 입력, n개 디스크 1개의 LVM 설정 시 n 입력)\e[0m"
        read DISK_COUNT

        if ! [[ "$DISK_COUNT" =~ ^[0-9]+$ ]] || [ "$DISK_COUNT" -eq 0 ]; then
            echo -e "\e[1;31m유효한 디스크 개수를 입력하세요.\e[0m"
            continue
        fi

        DISKS=()
        echo -e "\e[32mLVM 설정 원하는 디스크 이름을 입력하세요: \e[0m"
        echo -e "\e[32m(2개 이상 입력 시 공백으로 구분하여 입력. 예)/dev/xvdb /dev/xvdc /dev/xvdd) \e[0m"
        read -a DISK_INPUTS

        
        for DISK_INPUT in "${DISK_INPUTS[@]}"; do
            if [ -e "$DISK_INPUT" ]; then
                if [[ " ${DISKS[@]} " =~ " ${DISK_INPUT} " ]]; then
                    echo -e "\e[1;31m동일한 디스크를 중복하여 추가할 수 없습니다.\e[0m"
                    DISKS=()
                    break
                elif fdisk -l | grep -q "${DISK_INPUT}1";then
                    echo -e "\e[1;31m동일한 디스크를 중복하여 추가할 수 없습니다.\e[0m"
                    DISKS=()
                    break
                else
                    DISKS+=("$DISK_INPUT")
                fi
            else
                echo -e "\e[1;31m잘못 입력하였습니다. 정확한 디스크 장치 파일 명을 입력하시오.\e[0m"
                DISKS=()
                break
            fi
        done

        if [ "${#DISKS[@]}" -ne "$DISK_COUNT" ]; then
            echo -e "\e[1;31m입력한 디스크 개수가 원하는 디스크 개수와 일치하지 않습니다.\e[0m"
            DISKS=()
            continue
        else
            break
        fi
    done

    while true; do
        echo -e "\e[32m마운트할 디렉토리 경로를 입력하세요 (예: /data): \e[0m"
        read MOUNT_POINT
        mkdir -p ${MOUNT_POINT}
        if [ "$(ls -A ${MOUNT_POINT})" ];then
            echo -e "\e[1;31m해당 디렉토리 하위에 파일이 존재하여 마운트 할 수 없습니다.\e[0m"
        else
            break;
        fi
    done

    while true; do
        echo -e "\e[32mLVM 볼륨 그룹 이름을 입력하세요 (예: DataVG): \e[0m"
        read VG_NAME
        if vgs $VG_NAME > /dev/null 2>&1; then
            echo -e "\e[1;31m볼륨 그룹 '$VG_NAME'이(가) 이미 존재합니다. 다른 이름을 입력하세요.\e0m"
        else
            break
        fi
    done

    while true; do
        echo -e "\e[32mLVM 논리 볼륨 이름을 입력하세요 (예: datalv): \e[0m"
        read LV_NAME

        if [ -n "$(lvs --noheadings --select "lv_name='${LV_NAME}'" 2>/dev/null)" ]; then
            echo -e "\e[1;31m논리 볼륨 '$LV_NAME'이(가) 이미 존재합니다. 다른 이름을 입력하세요.\e[0m"
        else
            break
        fi
    done

    while true; do
        echo -e "\e[32m디스크 레이블 형식을 선택하세요 (msdos 또는 gpt(2TB이상일때), default: msdos): \e[0m"
        read LABEL_TYPE
        LABEL_TYPE=${LABEL_TYPE:-msdos}
        if [ "$LABEL_TYPE" == "msdos" ];then
            echo -e "msdos타입을 선택하였습니다."
            break
        elif [ "$LABEL_TYPE" == "gpt" ];then
            echo -e "gpt타입을 선택하였습니다."
            break
        else
            echo -e "\e[1;31m잘못 입력하였습니다. msdos타입과 gpt타입 중 하나를 선택하시오.\e[0m"
        fi
    done

    while true; do
        echo -e "\e[32m파티션 타입을 선택하세요 (ext4 또는 xfs. default: ext4): \e[0m"
        read PARTITION_TYPE
        PARTITION_TYPE=${PARTITION_TYPE:-ext4}
        if [ "$PARTITION_TYPE" == "ext4" ];then
            echo -e "ext4타입을 선택하였습니다."
            break
        elif [ "$PARTITION_TYPE" == "xfs" ];then
            echo -e "xfs타입을 선택하였습니다."
            break
        else
            echo -e "\e[1;31m잘못 입력하였습니다. ext4타입과 xfs타입 중 하나를 선택하시오.\e[0m"
        fi
    done

    for DISK in "${DISKS[@]}"; do
        parted $DISK mklabel $LABEL_TYPE
        parted $DISK mkpart primary $PARTITION_TYPE 0% 100%
        parted $DISK set 1 lvm on
    done

    vgcreate $VG_NAME $(printf "%s1 " "${DISKS[@]}")
    lvcreate -n $LV_NAME -l 100%FREE $VG_NAME
    echo -e "\e[32m!!!!!곧 파일시스템을 생성합니다.!!!!!\e[0m"
    echo -e "\e[32m!!!!!파일시스템 생성 중 아무 키도 입력 하지 마시오.!!!!!\e[0m"
    echo -e "\e[32m!!!!!엔터 입력 시 /etc/fstab에 정상적으로 등록되지 않을 수 있습니다.!!!!!\e[0m"
    sleep 3

    mkfs.$PARTITION_TYPE /dev/$VG_NAME/$LV_NAME
    
    echo -e "\e[32m마운트 플래그를 쉼표로 구분하여 공백 없이 입력 바랍니다.\e[0m"
    echo -e "\e[32m(예: defaults,noatime,usrquota,noexec)\e[0m"
    read MOUNT_FLAG
    echo ${MOUNT_FLAG}
    echo "/dev/$VG_NAME/$LV_NAME                   $MOUNT_POINT                $PARTITION_TYPE   $MOUNT_FLAG 0 0" | tee -a /etc/fstab
    systemctl daemon-reload
    mount /dev/$VG_NAME/$LV_NAME $MOUNT_POINT
    echo -e "\e[32m디스크 마운트 완료하였습니다.확인 바랍니다.\e[0m"
    sleep 1
    echo -e "\e[32m===================================df -h===================================\e[0m"
    df -h
    sleep 1
    echo -e "\e[32m================================/etc/fstab=================================\e[0m"
    cat /etc/fstab

    while true; do
        echo -e "\e[32m추가로 설정할 LVM이 있습니까? (y/n. default: n)\e[0m"
        read CHOOSE
        CHOOSE=${CHOOSE:-n}
        if [ "$CHOOSE" == "y" ] || [ "$CHOOSE" == "Y" ]; then
            ISEND=N
            break
        elif [ "$CHOOSE" == "n" ] || [ "$CHOOSE" == "N" ]; then            
            ISEND=Y
            break
        else
            echo -e "\e[32my 또는 n을 입력하세요.\e[0m"
        fi
    done
    
    if [ "$ISEND" == "Y" ]; then
        echo -e "\e[32m스크립트를 종료합니다.\e[0m"
        break
    elif [ "$ISEND" == "N" ]; then
        main
    fi
done
}

function extend(){
    
    while true; do
        echo -e "\e[32m기존 LVM 볼륨 그룹 이름을 입력하세요 (예: DataVG): \e[0m"
        read VG_NAME
        if ! vgs $VG_NAME > /dev/null 2>&1; then
            echo -e "\e[1;31m볼륨 그룹 '$VG_NAME'을 찾을 수 없습니다. 올바른 이름을 입력하세요.\e[0m"
        else
            break
        fi
    done

    while true; do
        echo -e "\e[32m기존 LV 이름을 입력하세요 (예: datalv): \e[0m"
        read LV_NAME

        if [ -n "$(lvs --noheadings --select "lv_name='${LV_NAME}'" 2>/dev/null)" ]; then
            break
        else
            echo -e "\e[1;31m볼륨 그룹 '$LV_NAME'을 찾을 수 없습니다. 올바른 이름을 입력하세요.\e[0m"
        fi
    done

    while true; do
        echo -e "\e[32m확장 할 디스크의 개수를 입력하세요: \e[0m"
        read DISK_COUNT

        if ! [[ "$DISK_COUNT" =~ ^[0-9]+$ ]] || [ "$DISK_COUNT" -eq 0 ]; then
            echo -e "\e[1;31m유효한 디스크 개수를 입력하세요.\e[0m"
            continue
        fi

        DISKS=()
        echo -e "\e[32mLVM 확장 원하는 디스크명을 공백으로 구분하여 입력하세요 (예:/dev/xvdb /dev/xvdc): \e[0m"
        read -a DISK_INPUTS

        for DISK_INPUT in "${DISK_INPUTS[@]}"; do
            if [ -e "$DISK_INPUT" ]; then
                if [[ " ${DISKS[@]} " =~ " ${DISK_INPUT} " ]]; then
                    echo -e "\e[1;31m동일한 디스크를 중복하여 추가할 수 없습니다.\e[0m"
                    DISKS=()
                    break
                else
                    DISKS+=("$DISK_INPUT")
                fi
            else
                echo -e "\e[1;31m잘못 입력하였습니다. 정확한 디스크 장치 파일 명을 입력하시오.\e[0m"
                DISKS=()
                break
            fi
        done

        if [ "${#DISKS[@]}" -ne "$DISK_COUNT" ]; then
            echo -e "\e[1;31m입력한 디스크 개수가 원하는 디스크 개수와 일치하지 않습니다.\e[0m"
            DISKS=()
            continue
        else
            break
        fi
    done

    while true; do
        echo -e "\e[32m기존 LVM에 속한 디스크의 label type을 참고하여 디스크 레이블 형식을 선택하세요 (msdos 또는 gpt(2TB이상일때), default: msdos): \e[0m"
        read LABEL_TYPE
        LABEL_TYPE=${LABEL_TYPE:-msdos}
        if [ "$LABEL_TYPE" == "msdos" ];then
            echo -e "msdos타입을 선택하였습니다."
            break
        elif [ "$LABEL_TYPE" == "gpt" ];then
            echo -e "gpt타입을 선택하였습니다."
            break
        else
            echo -e "\e[1;31m잘못 입력하였습니다. msdos타입과 gpt타입 중 하나를 선택하시오.\e[0m"
        fi
    done

    AS_IS_PARTITION_TYPE=`parted /dev/$VG_NAME/$LV_NAME print | tail -n 2 | awk '{print $5}' | head -1`

    for DISK in "${DISKS[@]}"; do
        parted $DISK mklabel $LABEL_TYPE
        parted $DISK mkpart primary $AS_IS_PARTITION_TYPE 0% 100%
        parted $DISK set 1 lvm on
    done
    
    for DISK in "${DISKS[@]}"; do
        echo ${DISK}1
        vgextend $VG_NAME ${DISK}1
    done

    lvextend -l +100%FREE /dev/$VG_NAME/$LV_NAME

    if [ "$AS_IS_PARTITION_TYPE" == "ext4" ]; then
        resize2fs /dev/$VG_NAME/$LV_NAME
    elif [ "$AS_IS_PARTITION_TYPE" == "xfs" ]; then
        xfs_growfs /dev/$VG_NAME/$LV_NAME
    fi

    echo -e "\e[32mLVM 확장이 완료되었습니다.\e[0m"
}

function install_lvm2(){

    if [ -f /etc/redhat-release ]; then
        OS="centos"
    elif [ -f /etc/lsb-release ]; then
        OS="ubuntu"
    else
        echo "지원하지 않는 운영체제입니다."
        exit 1
    fi

    # 운영체제별 패키지 설치
    if [ "$OS" == "centos" ]; then
        if ! rpm -q lvm2 >/dev/null 2>&1; then
            echo "lvm2 패키지가 설치되어 있지 않습니다. 설치 중..."
            sudo yum install -y lvm2
            echo "lvm2 패키지 설치가 완료되었습니다."
        else
            echo "lvm2 패키지가 이미 설치되어 있습니다."
        fi
    elif [ "$OS" == "ubuntu" ]; then
        if ! dpkg -s lvm2 >/dev/null 2>&1; then
            echo "lvm2 패키지가 설치되어 있지 않습니다. 설치 중..."
            sudo apt update
            sudo apt install -y lvm2
            echo "lvm2 패키지 설치가 완료되었습니다."
        else
            echo "lvm2 패키지가 이미 설치되어 있습니다."
        fi
    fi
}
function main(){
    while true; do
        echo -e "\e[32m다음 중 하나를 선택하세요:\e[0m"
        echo -e "\e[32m1: 새로운 LVM 생성\e[0m"
        echo -e "\e[32m2: 기존 LVM 확장\e[0m"
        read FUNCTION_CODE
        if [ "$FUNCTION_CODE" == "1" ]; then
            install_lvm2
            total
            break
        elif [ "$FUNCTION_CODE" == "2" ]; then
            install_lvm2
            extend
            break
        else
            echo -e "\e[1;31m잘못 입력하였습니다.\e[0m"
        fi
    done
}

main
