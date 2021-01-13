# README

Citaions

Setting up the AWS CLI
https://docs.aws.amazon.com/transcribe/latest/dg/setup-asc-awscli.html
Creating a Transcription Job
https://docs.aws.amazon.com/transcribe/latest/dg getting-started-asc-console.html

Installations

https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
이 링크로 가서 AWS CLI version2 를 해당 OS에 맞게 다운 받고 실행하세요.

설정을 다 마친 다음 필요한 gem을 install 하세요
terminal: $gem install "down"
in Gemfile: gem 'down'
terminal: $bundle add down

기능

lessonid, filename, s3 bucketname 이 주어졌을때 zoom format 에 맞는 json file을 return

코드 설명

1. 파일명 ls call 을 하기 (파일명이 겹치면 s3에 있는 파일이 덮어쎠집니다. 괜찮으면 performace를 위해 해당 코드 지워도 괜찮습니다)
2. 업로드
3. Transcribe (보통 6~12분 소요. 현제는 그 시간동안 기다리지 않고 그냥 get transcription job 합니다. fork 필요?)
4. get transcription job call (COMPLETED 또는 IN-PROGRESS를 return 합니다. COMPLETED 일시 transcript json 을 받을 수 있는 s3 uri도 return)
5. s3 uri에서 json 다운 받아서 zoom format으로 변환 (해당 json은 처음 나온 사람이 role 0 입니다. 하지만 90% 확률로 student가 누군지 맞추는 suggestion도 계산 됩니다.)
