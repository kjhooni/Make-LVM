LVM 자동화 스크립트 매뉴얼

구동 가능 환경
- OS: Ubuntu 18.x, 20.x, 22.x / CentOS 7.x / Rocky 8.x
- lvm2패키지 설치 必

Case
1. 새로운 LVM 생성 (1개 및 n개의 디스크를 하나의 LVM으로 구성)
- 1개의 디스크를 1개의 LVM으로 설정
(예: /dev/xvdb를 datalv로 설정)
- n개의 디스크를 1개의 LVM으로 설정
(예: /dev/xvdb, /dev/xvdc, /dev/xvdd를 backuplv로 설정)
- SSD / HDD 구분 없이 가능
2. 기존 LVM 확장
- 1개의 디스크를 기존 LVM에 확장
(예: /dev/xvdd를 DataVG에 extend)
- n개의 디스크를 기존 LVM에 확장
(예: /dev/xvdd, /dev/xvde, /dev/xvdf를 DataVG에 extend)

Case1. 새로운 LVM 생성
입력할 디스크의 개수를 입력하세요:
  - 1개 또는 n개 입력
LVM 설정 원하는 디스크 이름을 입력하세요 (예: /dev/xvdb /dev/xvdc): 
  - 디스크 장치 명 입력
  - n개 입력 시 space바로 분기하여 입력
  (ex)/dev/xvdb /dev/xvdc /dev/xvdd)
마운트 할 디렉토리 경로를 입력하세요 (예: /data): 
  - 입력한 디렉토리 하위에 데이터가 존재하면 안됨
LVM 볼륨 그룹 이름을 입력하세요 (예: DataVG):
  - 해당 볼륨그룹이 이미 존재하면 안됨
LVM 논리 볼륨 이름을 입력하세요 (예: datalv):
  - 해당 논리 볼륨이 이미 존재하면 안됨
디스크 레이블 형식을 선택하세요 (msdos 또는 gpt(2TB이상일때), default: msdos):
파티션 타입을 선택하세요 (ext4 또는 xfs, default: ext4):
마운트 플래그를 쉼표로 구분하여 공백 없이 입력 바랍니다.
(예: defaults,noatime,usrquota,noexec)
추가로 설정할 LVM이 있습니까? (y/n. default: n)
  - y입력 시 처음으로 돌아가서 스크립트 재실행
  - n입력 시 스크립트 종료
!!종료 후 정확히 마운트 되었는지 확인 必

Case2. 기존 LVM 확장
기존 LVM 볼륨 그룹 이름을 입력하세요 (예: DataVG):
기존 LV 이름을 입력하세요 (예: datalv):
확장 할 디스크의 개수를 입력하세요
  - 1개 또는 n개
LVM 확장 원하는 디스크 이름을 입력하세요 (예: /dev/xvdb /dev/xvdc):
  - 디스크 장치 명 입력
  - n개 선택 시 해당 개수만큼 space바로 분기하여 입력
기존 LVM에 속한 디스크의 label type을 참고하여 디스크 레이블 형식을 입력하세요
(msdos 또는 gpt(2TB이상일때), default: msdos):
  - !!기존 디스크의 label type과 같아야 합니다.
  - fdisk -l을 통해 확인 가능
  - 해당 입력을 끝으로 스크립트 종료
