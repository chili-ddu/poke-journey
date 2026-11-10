# 493종 원본 도트 확장

기존 프로젝트와 같은 [PMDCollab/SpriteCollab](https://github.com/PMDCollab/SpriteCollab)의 원본을 사용했다. 소스 커밋은 `e56caec3fda47cbd4b9d2177b3d1bc05f0ff7dc7`로 고정했다. 도감 1–493의 기본 모습과 이로치를 각각 `####/`, `####/shiny/`에 배치했다. 다른 폼·성별 변형을 추가한 묶음은 아니다.

각 폴더의 `credits.txt`가 해당 도트의 상세 기여자 기록이다. 기존 파일과 기여자 기록은 덮어쓰지 않았다. 추가한 원본 30,024개 파일의 Git blob ID·SHA-256·원격 경로는 [설치 기록](../../docs/pokemon_2x_rollout/source-install.json)에 있다. 원작 추출분과 기여자 작업의 조건은 [기존 출처 기록](CREDITS.md), 각 폴더의 기여자 기록 및 [원본 저장소 라이선스](https://github.com/PMDCollab/SpriteCollab/blob/e56caec3fda47cbd4b9d2177b3d1bc05f0ff7dc7/LICENSE.md)를 따른다.

기존 구구(0016) 이로치 메타데이터가 선언한 보조 동작 20개는 원격 이로치 폴더에 없었다. 기존 일반색·이로치 14개 시트에서 알파·위치가 일치하고 11색 대응에 충돌이 없음을 확인한 뒤 일반색 원본을 같은 대응표로 변환했다. 대응 근거가 없는 입 안의 `#9f0000`은 원본 그대로 보존했다. 이 보조 동작은 원격 이로치 원본 다운로드로 표기하지 않는다. 상세 픽셀 대응과 파일 해시는 [파생 기록](../../docs/pokemon_2x_rollout/derived-shiny.json)에 있다.

중간 프레임은 이 원본들에서 파생한 별도 리소스이며, [2배 프레임 기록](../motion_2x/README.md)을 참조한다.
