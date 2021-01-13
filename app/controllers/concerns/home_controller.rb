

class HomeController < ApplicationController

  def index
  require 'json'
  my_object = []
  reslist = []
  anal = []
  wdcnt = []
  calcstu = []
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
    wdcnt[ind] = [r0, r1]

  
  end

  @data = reslist[9]
  @objlist = my_object
  @sturole = [0, 1, 0, 0, 1, 1, 1, 1, 1, 0]
  @anal = anal
  @wdcnt = wdcnt
  
  end

  # def cnv(str)
  #   res = 0.0 + str.split(':')[2].to_f + (str.split(':')[1].to_f*60)
  #   return res
  # end

  def cmp
  #   require 'json'
  #   my_object = File.open("#{Rails.root}/ascripts/ringleT0.json", "r")
  #   a = JSON.parse(my_object.read)
  #   my_object1 = File.open("#{Rails.root}/zscripts/ringleT0.json", "r")
  #   b = JSON.parse(my_object1.read)

  #   # (0..9).to_a each do |ind|
      
  
  #   punctcnt = 0 #count punctuations since punctuations are included as items in conversation but not a segment in speaker labels
  #   tres = a['results']['items'] #temporary result which is not processed (raw data labeled per word and punctuation)
  #   segres = a['results']['speaker_labels']['segments'] #segments denote the item
  #   lessonid = 'LID from app'
  #   userid = 11111111
  #   userid1 = 'UID1 from app'
  #   userid2 = 'UID2 from app'
  #   tutorid = 11
  #   rolary = []
  #   role = 0
  
  #   segres.each do |what|
  #     rolex = (what['speaker_label'] === 'spk_0') ? 0 : 1
  #     what['items'].each do |which|
  #       rolary.append(rolex)
  #     end
  #   end
  
  #   res=[]
  #   cur = 0
  #   nxt = 1
  #   lim = tres.length()
  #   r0 = 0.0
  #   r1 = 0.0
  #   pr0 = 0.0
  #   pr1 = 0.0
  #   ar0 = 0.0
  #   ar1 = 0.0
  #   conf0 = 0.0
  #   conf1 = 0.0
  #   l0 = 0.0
  #   l1 = 0.0

  
  #   while cur < lim
  #     ccontent = tres[cur]['alternatives'][0]['content']
  #     stime = tres[cur]['start_time'].to_f
  #     etime = tres[cur]['end_time'].to_f
  #     role = rolary[cur - punctcnt]
  #     userid = ((role == 0)? userid1 : userid2)

  #     if (tres[cur]['type']=='punctuation')
  #       if tres[cur]['alternatives'][0]['content'] === '?'
  #         if role == 0
  #           r0 +=1
  #         else
  #           r1 +=1
  #         end
  #       end

  #       if tres[cur]['alternatives'][0]['content'] === '.'
  #         if role == 0
  #           pr0 +=1.0
  #         else
  #           pr1 +=1.0
  #         end
  #       end

  #       cur += 1
  #       nxt = cur +1

  #       next
  #     end
      
  #     if tres[cur]['alternatives'][0]['content'] === 'a' or tres[cur]['alternatives'][0]['content'] === 'an' or tres[cur]['alternatives'][0]['content'] === 'the'
  #       if role == 0
  #         ar0 +=1
  #       else
  #         ar1 +=1
  #       end
  #     end

  #     if role == 0
  #       conf0+=(tres[cur]['alternatives'][0]['confidence'].to_f)
  #       l0 +=1
  #     else
  #       conf1+=(tres[cur]['alternatives'][0]['confidence'].to_f)
  #       l1 +=1
  #     end

  #     res << {
  #       "role": role,
  #       "content": ccontent,
  #       "start_time": stime
  #     }
  #     cur += 1
  #     nxt = cur +1
  #   end
    

 

  #   resb=[]
  #   i = 0
  #   curb = 0
  #   limb = b.length()
  #   acc = 0

  #   while ((curb < limb) && (i < res.length)) 
  #     stime = cnv(b[curb].inspect.split('=>')[5].to_s[2..-14].to_s)
  #     etime = cnv(b[curb].inspect.split('=>')[6].to_s[2..-3].to_s)
  #     ths = res[i].inspect.split(', :')[1].to_s[10..-2].to_s
  #     tms = res[i].inspect.split(', :')[2].to_s[12..-2].to_f
      
  #     # resb << {
  #     #   'btimes': stime,
  #     #   'btimee': etime,
  #     #   'restime': tms,
  #     #   'val': (tms >= stime)
  #     # }

  #     if !(tms >= stime)
  #       i+=1
  #     elsif (tms< etime)
  #       if b[curb].inspect.split('=>')[4].to_s[1..-16].to_s.include? ths
  #         acc += 1
  #       end
  #        i+=1
  #     else
  #       curb +=1
  #     end

  #     # resb << {
  #     #   "content": b[curb].inspect.split('=>')[4].to_s[1..-16].to_s,
  #     #   # "start_time": "#{Time.at(stime).utc.strftime("%T.%L")}",
  #     #   "start_time": stime,
  #     #   "end_time": etime,
  #     #   'a':  res[curb].inspect.split(', :')[2].to_s[12..-2].to_f
  #     # }
  #     # i += 1
  #     # curb += 1
  #   end

  #   # obj    = JSON.pretty_generate(resb)
  #   @data = acc.to_f/res.length.to_f
  #   @roleals = (r0/pr0).to_s.concat(" "+(r1/pr1).to_s)
  #   @rolarticles = (ar0/pr0).to_s.concat(" "+(ar1/pr1).to_s)
  #   @tot = (r0/pr0+ar0/pr0).to_s.concat(" "+(r1/pr1+ar1/pr1).to_s)
  #   @conf = (conf0/l0).to_s.concat(" "+(conf1/l1).to_s)
  
  end

  
end
