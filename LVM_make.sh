#!/bin/bash

while true; do
    echo -e "\e[32m새로운 디스크 디바이스 이름을 입력하세요 (예: /dev/xvdb): \e[0m"
    read NEW_DISK

    if [ -e "$NEW_DISK" ]; then
        break
    else
        echo "============================================================"
        echo "잘못 입력하였습니다. 정확한 디스크 장치파일 명을 입력하시오."
        echo "============================================================"
    fi
done

echo -e "\e[32m마운트할 디렉토리 경로를 입력하세요 (예: /data): \e[0m"
read MOUNT_POINT

echo -e "\e[32mLVM 볼륨 그룹 이름을 입력하세요: \e[0m"
read VG_NAME

echo -e "\e[32mLVM 논리 볼륨 이름을 입력하세요: \e[0m"
read LV_NAME

while true; do
    echo -e "\e[32m디스크 레이블 형식을 선택하세요 (gpt(2TB이상일때) 또는 msdos, default: msdos): \e[0m"
    read LABEL_TYPE
    LABEL_TYPE=${LABEL_TYPE:-msdos}
    echo "기본값인 msdos형식을 선택하였습니다."
    if [ "$LABEL_TYPE" != "gpt" ] && [ "$LABEL_TYPE" != "msdos" ]; then
        echo "==============================================================="
        echo "잘못 입력하였습니다. gpt형식과 msdos형식 중 하나를 선택하시오."
        echo "==============================================================="
    else
        break
    fi
done

while true; do
    echo -e "\e[32m파티션 타입을 선택하세요 (ext4 또는 xfs. default: ext4): \e[0m"
    read PARTITION_TYPE
    PARTITION_TYPE=${PARTITION_TYPE:-ext4}
    echo "기본값인 ext4타입을 선택하였습니다."

    if [ "$PARTITION_TYPE" != "ext4" ] && [ "$PARTITION_TYPE" != "xfs" ]; then
        echo "=============================================================="
        echo "잘못 입력하였습니다. ext4타입과 xfs타입 중 하나를 선택하시오."
        echo "=============================================================="
    else
        break
    fi
done

while true; do
    echo -e "\e[32m두 개의 디스크를 하나의 LVM으로 결합하시겠습니까? (y/n): \e[0m"
    read JOIN_LVM

    if [ "$JOIN_LVM" == "y" ]; then
        echo -e "\e[32m두 번째 디스크 디바이스 이름을 입력하세요 (예: /dev/xvdc): \e[0m"
        read SECOND_DISK

        if [ -e "$SECOND_DISK" ]; then
          if [ "$SECOND_DISK" == "$NEW_DISK" ]; then
              echo "============================================================"
              echo "잘못 입력하였습니다. 두 번째 디스크와 첫 번째 디스크는 동일할 수 없습니다."
              echo "============================================================"
          else
              sudo parted ${NEW_DISK} mklabel ${LABEL_TYPE}
              sudo parted ${NEW_DISK} mkpart primary ${PARTITION_TYPE} 0% 100%
              sudo parted ${NEW_DISK} set 1 lvm on
              sudo parted ${SECOND_DISK} mklabel ${LABEL_TYPE}
              sudo parted ${SECOND_DISK} mkpart primary ${PARTITION_TYPE} 0% 100%
              sudo parted ${SECOND_DISK} set 1 lvm on
              sudo mkfs.${PARTITION_TYPE} ${NEW_DISK}1
              sudo mkfs.${PARTITION_TYPE} ${SECOND_DISK}1
              sudo vgcreate ${VG_NAME} ${NEW_DISK}1 ${SECOND_DISK}1
              sudo lvcreate -n ${LV_NAME} -l 100%FREE ${VG_NAME}
              sudo mkfs.${PARTITION_TYPE} /dev/${VG_NAME}/${LV_NAME}
              sudo mkdir -p ${MOUNT_POINT}
              echo "/dev/${VG_NAME}/${LV_NAME} ${MOUNT_POINT} ${PARTITION_TYPE} defaults 0 0" | sudo tee -a /etc/fstab
              sudo systemctl daemon-reload
              sudo mount /dev/${VG_NAME}/${LV_NAME} ${MOUNT_POINT}
              echo "디스크 마운트 완료"
              break
          fi
        else
            echo "============================================================"
            echo "잘못 입력하였습니다. 정확한 디스크 장치파일 명을 입력하시오."
            echo "============================================================"
        fi
    elif [ "$JOIN_LVM" == "n" ]; then
        sudo parted ${NEW_DISK} mklabel ${LABEL_TYPE}
        sudo parted ${NEW_DISK} mkpart primary ${PARTITION_TYPE} 0% 100%
        sudo parted ${NEW_DISK} set 1 lvm on
        sudo mkfs.${PARTITION_TYPE} ${NEW_DISK}1
        sudo vgcreate ${VG_NAME} ${NEW_DISK}1
        sudo lvcreate -n ${LV_NAME} -l 100%FREE ${VG_NAME}
        sudo mkfs.${PARTITION_TYPE} /dev/${VG_NAME}/${LV_NAME}
        sudo mkdir -p ${MOUNT_POINT}
        echo "/dev/${VG_NAME}/${LV_NAME} ${MOUNT_POINT} ${PARTITION_TYPE} defaults 0 0" | sudo tee -a /etc/fstab


        sudo systemctl daemon-reload
        sudo mount /dev/${VG_NAME}/${LV_NAME} ${MOUNT_POINT}

        echo "디스크 마운트 완료"
        break
    else
        echo "============================================================"
        echo "잘못 입력하였습니다. 'y' 또는 'n' 중 하나를 선택하시오."
        echo "============================================================"
    fi
done