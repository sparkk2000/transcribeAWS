


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

    @alert = system("aws", "s3", "cp", "s3://ringle-transcribe-test/#{params[:jobid]}.json", "#{Rails.root}/cache/temp.json")

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
  #flip roles

  def read

    if params[:who].present?
      who = params[:who]
    else
      who = "Joanna"
    end
    
    script1 = "In most major cities around the world these days, it's easy to find people riding motorized boards down the street. In the past, most people chose to walk short distances. Now, the Uber-style sharing of electric scooters is quickly becoming a part of the younger generation's transportation options.
  
  
    Users of personal mobility devices often travel on the sidewalk, not on the road or in the bikeways, which causes many problems. In many cities, the number of electric scooters that collide with pedestrians is increasing. More and more accidents between mobility device riders and moving vehicles, or riders tripping themselves are reported. Recent reports of fatal accidents have deepened public anxiety.
    
    
    Many municipal and central governments have begun to enact regulations on electric scooters, enforcing tighter controls like designating speed limits. Some countries have regulations that use of personal mobility devices are only for adults with a valid vehicle or motorcycle license. Or they restrict riding to roads and bike lanes only, not on walkways, in defined locations that will not pose a danger to pedestrians. In some cities, “hiring” electric scooters is defined as illegal, depriving the service providers of entire markets.
    
    
    Rideshare users claim the right to “travel.” Conversely, pedestrians demand their right to travel “safely.” At the same time, car drivers on the road embody the right to transportation without worrying about different types of wheeled devices.
    
    What do you think about personal mobility devices, such as electric scooters?
    "

    script2 = "The year 2020 was when a pandemic put a stop to everyone's ordinary lives. Inevitably, the industries most closely related to daily living were hit hard. Deserted airports and grounded fleets have caused colossal losses in aviation, travel, and hospitality businesses worldwide. Strings of infections in indoor spaces, including fitness centers, concert halls, private tutoring academies, restaurants, and bars, have vaporized more than 80 percent of offline business revenues. Consequently, millions of people around the world who used to work in those segments lost their jobs and have been forced to work on temporary terms, such as in delivery services, barely managing unstable daily life.


    In late 2020, pharmaceutical companies in the United States, the United Kingdom, China, and Russia finally began supplying vaccines for the unprecedented health crisis. Global pharmaceutical giants such as Pfizer, Jansen (Johnson and Johnson) and AstraZeneca, and Boston-based biotech company Moderna, have announced their success in developing vaccines with a 70 to 95 percent efficacy rate. Governments around the world have swiftly approved use, which was an extraordinary move itself, and begun giving shots to their people.
    
    
    Returning to the normal days as soon as possible is what people around the globe most look forward to now. It all depends on whether or not the vaccines currently in dissemination can effectively prevent the ever-spreading coronavirus. What if people who get the shots still find themselves infected? What if there is a new coronavirus variant that renders the vaccine inefficacious? Then the whole world would have to be locked down again. Furthermore, even with the assumption that the current vaccines are uniformly effective, it is also crucial to answer whether or not the production, distribution, and actual roll-out of the vaccine on a massive scale are possible.
    
    
    In 2021, will we be able to restore our daily lives after vaccinating?
    "
    
    script3 = "The number of pets is increasing rapidly around the world. According to a study conducted in 22 countries, more than half of the world’s population owns pets. Countries with high percentage of households with pets were largely concentrated in the Americas, such as Argentina (80%), Mexico (80%), Brazil (75%), Russia (73%), and the U.S. (70%). Asian countries such as Korea (31%), Hong Kong (35%), and Japan (37%) showed relatively less interest.


    Pet owners prefer dogs (33%), cats (23%), fish (12%), and birds (6%) in this order. That said, cat adoption rates were higher than that of dogs in Russia, Sweden, Belgium, France, and Germany. There are also twice as many pet cats than dogs in Russia, indicating differences in pet preference by country.
    
    
    Reasons for the recent increase in the number of households with pets include declining birth rates, rising global income levels, and increased interest in animals due to images shared on social media.
    
    
    However, the increase in pets is aggravating environmental destruction caused by more water and food consumption as well as related social costs and animal rights infringements. Consequently, improved awareness around the coexistence of pets and humans, legal reform, and infrastructure are urgently needed.
    "

    if params[:script].present?
      case params[:script]
      when '1'
        scr = script1
      when '2'
        scr = script2
      when '3'
        scr = script3
      end
    else
      scr = script1
    end
    
    
    if Dir.entries("#{Rails.root}/app/assets/audio/").include? "#{who}#{params[:script]}.mp3"
      ret = true
    else
      ret = (system("aws", "polly", "synthesize-speech", "--output-format", "mp3", "--voice-id", "#{who}", "--text", "#{scr}", "#{Rails.root}/app/assets/audio/#{who}#{params[:script]}.mp3"))
    end


    @success = ret
    @data = who
    @str = scr
    @list = Dir.entries("#{Rails.root}/app/assets/audio/")
    @scrnum = params[:script]
    @filename = "#{who}#{params[:script]}"
    
  end

  def rmsilence
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


    cuttime = segres[0]['start_time'].to_f

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
      stime = tres[cur]['start_time'].to_f-cuttime
      #start time of first word in message
      etime = tres[cur]['end_time'].to_f-cuttime
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
          etime = tres[nxt]['end_time'].to_f-cuttime
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
      
      if (etime-stime) > 240
        res= []
        cuttime = tres[cur+1]['start_time'].to_f
      end

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

    system("ffmpeg", "-y", "-i", "#{Rails.root}/app/assets/audio/#{aud}", "-ss", "#{cuttime}", "-acodec", "copy", "#{Rails.root}/app/assets/audio/conv#{aud}")
    @data = res
    @analy = (analy == 0)
    @aud = "conv#{aud}"
    @job_id = params[:jobid]
    @cuttime = cuttime
  end



end
