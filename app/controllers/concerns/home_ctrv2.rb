

class HomeController < ApplicationController

  def index
  require 'json'
  my_object = []
  reslist = []
  anal = []
  (0..9).to_a.each do |ind|
    my_object[ind] = File.open("#{Rails.root}/ascripts/ringleT#{ind}.json", "r")
    a= JSON.parse(my_object[ind].read)
  

    punctcnt = 0 #count punctuations since punctuations are included as items in conversation but not a segment in speaker labels
    tres = a['results']['items'] #temporary result which is not processed (raw data labeled per word and punctuation)
    segres = a['results']['speaker_labels']['segments'] #segments denote the item
    lessonid = 'LID from app'
    userid = 11111111
    userid1 = 'UID1 from app'
    userid2 = 'UID2 from app'
    tutorid = 11
    rolary = []
    role = 0

    segres.each do |what|
      rolex = (what['speaker_label'] === 'spk_0') ? 0 : 1
      what['items'].each do |which|
        rolary.append(rolex)
      end
    end

    res=[]
    cur = 0
    nxt = 1
    lim = tres.length()
    sptime0 = 0.0
    sptime1 = 0.0
    r0 = 0
    r1 = 0

    while cur < lim
      ccontent = tres[cur]['alternatives'][0]['content']
      stime = tres[cur]['start_time'].to_f
      etime = tres[cur]['end_time'].to_f
      role = rolary[cur - punctcnt]
      userid = ((role == 0)? userid1 : userid2)

      while nxt < lim 
        if (tres[nxt]['type']=='punctuation')
          symbol = tres[nxt]['alternatives'][0]['content']
          ccontent.concat(symbol)
          punctcnt += 1
          if symbol == '.' && ccontent.split(" ").size> 10
            cur += 1
            nxt += 1
            break
          end
        elsif role != rolary[nxt - punctcnt] 
          break
        else 
          ccontent.concat(" "+tres[nxt]['alternatives'][0]['content'])
          etime = tres[nxt]['end_time'].to_f

        end
        cur += 1
        nxt += 1
      end 

      res << {
        "lesson_id": lessonid,
        "user_id": userid,
        "role": role,
        "content": ccontent,
        "start_time": "#{Time.at(stime).utc.strftime("%T.%L")}",
        "end_time": "#{Time.at(etime).utc.strftime("%T.%L")}"
      }

      cur += 1
      nxt = cur +1
      if (etime - stime)/ccontent.split(' ').length.to_f < 3 && res.length > 2
        if role==1
          sptime1 += (etime - stime)/ccontent.split(' ').length.to_f 
          r1 += 1
        else
          sptime0 += (etime - stime)/ccontent.split(' ').length.to_f 
          r0 += 1
        end
      end
    end

    obj    = JSON.pretty_generate(res)

    reslist[ind] = obj
    anal[ind] = [(sptime0/(res.length.to_f-4.0)), (sptime1/(res.length.to_f-4.0))]
  end
  
  @data = reslist[0]
  @anal = anal
  end

end
