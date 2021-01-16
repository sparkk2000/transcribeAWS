

class HomeController < ApplicationController

  def bucketcontents(buck)
    #aws cli call to get list of uploads in bucket
    stdin, stdout, stderr = Open3.popen3("aws", "s3", "ls", "#{buck}")
    uplist= stdout.read.split("\n")
    uploadlist = []
    uplist.each do |elem|
      uploadlist.append(elem.split(' ')[3])
    end
    return uploadlist
  end
  # returns bucket contents

  def checknupload(ulist, filename, bucketname)
    if !(ulist.include? filename)
      if !(system("aws", "s3", "cp", "#{Rails.root}/app/assets/audio/#{filename}", bucketname))
        return "upload failed!!!"
      end
    else
      return "filename exists"
    end
  end
  # check if filename is exists in s3

  def index
  end

  def create
    if params.has_key? (:SID) and params.has_key? (:TID) and params.has_key? (:LID) and params.has_key? (:filename)
      user_id = params["SID"]
      tutor_id = params["TID"]
      lessonid = params["LID"] #also acts as the unique job id
      jobid = "ringletest".concat(lessonid)
      filename = params["filename"]
      bucketname = "s3://ringle-transcribe-test/"
    else
      return
    end
    #parameters

    dbfile = File.read("#{Rails.root}/transcribejob.json")
    db = JSON.parse(dbfile)

    cmdcall = {
      "TranscriptionJobName": "#{jobid}",
      "LanguageCode": "en-US",
      "MediaSampleRateHertz": 32000,
      "MediaFormat": "mp4",#m4a is the audio portion of mp4
      "Media": {
        "MediaFileUri": "#{bucketname}#{filename}"},
      "Settings": {
        "ShowSpeakerLabels": true,
        "MaxSpeakerLabels": 2,
        "ChannelIdentification": false,
        "ShowAlternatives": false
      }
      }.to_json
      #json with settings for transcribe
    
    uploadlist= bucketcontents(bucketname)
    #aws cli call to get list of uploads in bucket

    alert = checknupload(uploadlist, filename, bucketname)
    #check if already uploaded into bucket if not, upload

    if !system("aws", "transcribe", "start-transcription-job", "--region", "ap-northeast-2", "--output-bucket-name", "#{bucketname[5..-2]}", "--cli-input-json", "#{cmdcall}")
      alert = "transcription failed!!! (or already started)"
    else 
      db["tjobs"].append({
        "job_id": jobid, "start_time": Time.now, "user_id": user_id, "tutor_id": tutor_id, "status": "IN_PROGRESS", "recom": 0, "aud": "#{filename}"
        #deleted url key
      })
      File.write("#{Rails.root}/transcribejob.json", JSON.dump(db))
      alert = "uploaded and transcription in progress"
    end
    #call transcription and handle error

    @ret = alert
    #messages
  end
  # upload and start transcription

  def db

    # require "down"

    @joblist=[]

    dbfile = File.read("#{Rails.root}/transcribejob.json")
    db = JSON.parse(dbfile)
    
    db["tjobs"].each do |tjob|
      if tjob["status"] == "COMPLETED"
        @joblist.append(tjob)
        next
      end
      (stdin, stdout, stderr = Open3.popen3("aws", "transcribe", "get-transcription-job", "--region", "ap-northeast-2", "--transcription-job-name", "#{tjob["job_id"]}"))
      output = JSON.parse(stdout.read)
      if output['TranscriptionJob']['TranscriptionJobStatus'] == "COMPLETED"
        tjob["status"] = "COMPLETED"
        # tjob["url"] = output['TranscriptionJob']['Transcript']['TranscriptFileUri']
      end
      @joblist.append(tjob)
    end
    # get transcription job

    File.write("#{Rails.root}/transcribejob.json", JSON.dump(db))
    #db file updated
    

  end
  # list jobs

  def cmp
    
    user_id = params[:userid]
    tutor_id = params[:tutorid]
    lesson_id = params[:jobid][10..]
    recom = params[:recom].to_i
    aud = params[:aud]
    # jsontrans = params[:url]
    #jsontrans stores the uri with json file

    # my_object = Down.download(jsontrans)
    #download with down api because open uri is buggy

    system("aws", "s3", "cp", "s3://ringle-transcribe-test/#{params[:jobid]}.json", "#{Rails.root}/cache/temp.json")

    my_object = File.open("#{Rails.root}/cache/temp.json","r")
    a= JSON.parse(my_object.read)
    #Load file

    punctcnt = 0 #count punctuations since punctuations are included as items in conversation but not a segment in speaker labels
    tres = a['results']['items'] #raw data labeled per word and punctuation
    segres = a['results']['speaker_labels']['segments'] #segments denote the item's speaker and duration
    #fill these later with ids from app

    rolary = []
    #array with roles 

    recomx = ((recom == 0) ? 1: 0)
    segres.each do |what|
      rolex = (what['speaker_label'] === 'spk_0') ? recom : recomx
      what['items'].each do |which|
        rolary.append(rolex)
      end
    end
    #roles are in a parallel array so, extract only the roles in a different array
    #also, punctuation dont have role labels

    res=[]
    #result array
    cur = 0
    nxt = 1
    #indexes for tres to concat words of the same sentence and role together
    sptime0 = 0.0
    sptime1 = 0.0
    #message duration / num words

    while cur < tres.length()
      ccontent = tres[cur]['alternatives'][0]['content']
      #ccontent to be elongated, currently the first word 
      stime = tres[cur]['start_time'].to_f
      #start time of first word in message
      etime = tres[cur]['end_time'].to_f
      #end time first word (will be changed upon elongation of message)
      role = rolary[cur - punctcnt]
      #current role (punctuation count was subtracted from current index because punctuation were not given roles)
      userid = role == 0 ? user_id : tutor_id
      #userid depends on role

      while nxt < tres.length() 
        if (tres[nxt]['type']=='punctuation')
          symbol = tres[nxt]['alternatives'][0]['content']
          ccontent.concat(symbol)
          punctcnt += 1 #remember to increment punctuation count
          if symbol == '.' && ccontent.split(" ").size> 10
            cur += 1
            nxt += 1
            break
          end
          #if message becomes too long, cut
        elsif role != rolary[cur - punctcnt]
          break
          #if role changes, cut
        else 
          ccontent.concat(" "+tres[nxt]['alternatives'][0]['content'])
          etime = tres[nxt]['end_time'].to_f
        end
        cur += 1
        nxt += 1
      end 
      #elongate message

      res << {
        "lesson_id": lesson_id,
        "user_id": userid,
        "role": role,
        "content": ccontent,
        "start_time": "#{Time.at(stime).utc.strftime("%T.%L")}",
        "end_time": "#{Time.at(etime).utc.strftime("%T.%L")}"
      }
      #add to result array upon elongation

      if (etime - stime)/ccontent.split(' ').length.to_f < 3 && res.length > 2
        if role== 1
          sptime1 += (etime - stime)/ccontent.split(' ').length.to_f 
        else
          sptime0 += (etime - stime)/ccontent.split(' ').length.to_f 
        end
      end
      #add average word duration 

      cur += 1
      nxt = cur +1
      #increment index

    end

    obj    = JSON.pretty_generate(res)
    #prettify for debugging
    analy = (sptime0/(res.length.to_f-2.0) < sptime1/(res.length.to_f-2.0)) ? 1 : 0
    #divide by number of entries

    @data = res
    @analy = (analy == 0)
    @aud = aud
    @job_id = params[:jobid]
    #data

  end
  # show json

  def change
    job_id = params[:jobid]

    dbfile = File.read("#{Rails.root}/transcribejob.json")
    db = JSON.parse(dbfile)
    
    db["tjobs"].each do |tjob|
      if tjob["status"] == "IN_PROGRESS"
        next
      end
      if tjob["job_id"] == job_id
        tjob["recom"] = ((tjob["recom"]==0)? 1 : 0)
        break
      end
    end
    # get transcription job

    File.write("#{Rails.root}/transcribejob.json", JSON.dump(db))
    #db file updated

    respond_to do |format|
      format.html { redirect_to home_db_path, notice: "DB was successfully updated." }
    end

  end
end
