#!/bin/bash

###################notice###################
#관리자권한을 가진 유저만 실행 가능합니다.

function total(){
while true; do
    echo -e "\e[32m                     fdisk -l                      \e[0m"
    echo -e "\e[32m=============================================================\e[0m"
    sleep 1
    fdisk -l
    sleep 2
    echo -e "\e[32m입력할 디스크의 개수를 입력하세요: \e[0m"
    read DISK_COUNT

    if ! [[ "$DISK_COUNT" =~ ^[0-9]+$ ]] || [ "$DISK_COUNT" -eq 0 ]; then
        echo -e "\e[1;31m유효한 디스크 개수를 입력하세요.\e[0m"
        exit 1
    fi

    DISKS=()
    while [ ${#DISKS[@]} -lt "$DISK_COUNT" ]; do
        echo -e "\e[32mLVM 설정 원하는 디스크 이름을 입력하세요 (예: /dev/xvdb): \e[0m"
        read DISK_INPUT

        if [ -e "$DISK_INPUT" ]; then
            if [[ " ${DISKS[@]} " =~ " ${DISK_INPUT} " ]]; then
                echo -e "\e[1;31m동일한 디스크를 중복하여 추가할 수 없습니다.\e[0m"
            else
                DISKS+=("$DISK_INPUT")
            fi
        else
            echo -e "\e[1;31m잘못 입력하였습니다. 정확한 디스크 장치 파일 명을 입력하시오.\e[0m"
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
        echo -e "\e[32mLVM 볼륨 그룹 이름을 입력하세요: \e[0m"
        read VG_NAME
        if vgs $VG_NAME > /dev/null 2>&1; then
            echo -e "\e[1;31m볼륨 그룹 '$VG_NAME'이(가) 이미 존재합니다. 다른 이름을 입력하세요.\e0m"
        else
            break
        fi
    done

    while true; do
        echo -e "\e[32mLVM 논리 볼륨 이름을 입력하세요: \e[0m"
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
            echo -e "\e[32mmsdos타입을 선택하였습니다.\e[0m"
            break
        elif [ "$LABEL_TYPE" == "gpt" ];then
            echo -e "\e[32mgpt타입을 선택하였습니다.\e[0m"
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
            echo -e "\e[32mext4타입을 선택하였습니다.\e[0m"
            break
        elif [ "$PARTITION_TYPE" == "xfs" ];then
            echo -e "\e[32mxfs타입을 선택하였습니다.\e[0m"
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
    mkfs.$PARTITION_TYPE /dev/$VG_NAME/$LV_NAME
    echo -e "\e[32m마운트 플래그를 쉼표로 구분하여 공백 없이 입력 바랍니다.\e[0m"
    echo -e "\e[32mex)defaults,noatime,usrquota,noexec\e[0m"
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
        echo -e "\e[32m기존 LVM 볼륨 그룹 이름을 입력하세요: \e[0m"
        read VG_NAME
        if ! vgs $VG_NAME > /dev/null 2>&1; then
            echo -e "\e[1;31m볼륨 그룹 '$VG_NAME'을 찾을 수 없습니다. 올바른 이름을 입력하세요.\e[0m"
        else
            break
        fi
    done

    while true; do
        echo -e "\e[32m기존 LV 이름을 입력하세요: (ex) datalv, backuplv 등)\e[0m"
        read LV_NAME

        if [ -n "$(lvs --noheadings --select "lv_name='${LV_NAME}'" 2>/dev/null)" ]; then
            break
        else
            echo -e "\e[1;31m볼륨 그룹 '$LV_NAME'을 찾을 수 없습니다. 올바른 이름을 입력하세요.\e[0m"
        fi
    done


    echo -e "\e[32m추가할 디스크 이름을 입력하세요 (예: /dev/xvdc): \e[0m"
    read NEW_DISK

    while true; do
        if [ ! -e "$NEW_DISK" ]; then
            echo -e "\e[1;31m디스크를 찾을 수 없습니다. 올바른 디스크 장치 파일 명을 입력하세요.\e[0m"
        else
            break
        fi
    done

    #LABEL_TYPE 입력
    ##기존 디스크와 라벨 타입이 같아야함
    ##기존 디스크 라벨타입 출력
    
    while true; do
        echo -e "\e[32m기존 LVM에 속한 디스크의 label type을 참고하여 디스크 레이블 형식을 선택하세요 (msdos 또는 gpt(2TB이상일때), default: msdos): \e[0m"
        read LABEL_TYPE
        LABEL_TYPE=${LABEL_TYPE:-msdos}
        if [ "$LABEL_TYPE" == "msdos" ];then
            echo -e "\e[32mmsdos타입을 선택하였습니다.\e[0m"
            break
        elif [ "$LABEL_TYPE" == "gpt" ];then
            echo -e "\e[32mgpt타입을 선택하였습니다.\e[0m"
            break
        else
            echo -e "\e[1;31m잘못 입력하였습니다. msdos타입과 gpt타입 중 하나를 선택하시오.\e[0m"
        fi
    done


    AS_IS_PARTITION_TYPE=`parted /dev/$VG_NAME/$LV_NAME print | tail -n 2 | awk '{print $5}' | head -1`


    parted $NEW_DISK mklabel $LABEL_TYPE
    parted $NEW_DISK mkpart primary $AS_IS_PARTITION_TYPE 0% 100%
    parted $NEW_DISK set 1 lvm on


    # 디스크를 볼륨 그룹에 추가
    vgextend $VG_NAME ${NEW_DISK}1

    # 볼륨 그룹 확장
    lvextend -l +100%FREE /dev/$VG_NAME/$LV_NAME

    # 파일 시스템 크기 조정 (ext4 또는 xfs에 따라 다름)
    if [ "$AS_IS_PARTITION_TYPE" == "ext4" ]; then
        resize2fs /dev/$VG_NAME/$LV_NAME
    elif [ "$AS_IS_PARTITION_TYPE" == "xfs" ]; then
        xfs_growfs /dev/$VG_NAME/$LV_NAME
    fi

    echo -e "\e[32mLVM 확장이 완료되었습니다.\e[0m"
}

function os_extend(){
    echo -e "\e[32mOS디스크 확장\e[0m"
}

function main(){
    echo -e "\e[32m다음 중 하나를 선택하세요:\e[0m"
    echo -e "\e[32m1: 새로운 LVM 생성 (여러 디스크를 하나의 LVM으로 합치기)\e[0m"
    echo -e "\e[32m2: 기존 LVM 확장하기\e[0m"
    echo -e "\e[32m3: 운영 체제 볼륨 확장하기\e[0m"
    read FUNCTION_CODE
    if [ "$FUNCTION_CODE" == "1" ]; then
        total
    elif [ "$FUNCTION_CODE" == "2" ]; then
        extend
    elif [ "$FUNCTION_CODE" == "3" ]; then
        os_extend
    fi
}

main