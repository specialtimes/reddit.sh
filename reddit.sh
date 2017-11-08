#!/bin/bash

debecho () {
  if [ ! -z "$DEBUG" ]; then
     echo "$1" >&2
#         ^^^ to stderr
  fi
}

webecho () {
  if [ ! -z "$WEB" ]; then
    echo "New $1 <a href=$2>$2</a><br>"
  else
    echo "Grabbing $1 $2"
  fi
}

user=$1
cookie="/tmp/reddit"
skipfn=skip.txt
baseurl=
DEBUG=

rm -rf $cookie

if ! [[ -d $user ]]; then
  mkdir $user
fi
if [ ! -z "$2" ]; then
  WEB=$2
else
  WEB=
fi

curl -s --cookie-jar $cookie "https://www.reddit.com/over18?dest=https"%"3A"%"2F"%"2Fwww.reddit.com"%"2Fr"%"2Fnsfw" -H "Host: www.reddit.com" -H "User-Agent: Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:54.0) Gecko/20100101 Firefox/54.0" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Accept-Language: en-US,en;q=0.5" --compressed -H "Referer: https://www.reddit.com/" -H "Content-Type: application/x-www-form-urlencoded" -H "DNT: 1" -H "Connection: keep-alive" -H "Upgrade-Insecure-Requests: 1" --data "over18=yes"

url=https://www.reddit.com/user/$user/submitted
pagenum=0
countpls=0

while true; do
  if [[ $pagenum == 0 ]]; then
    url=https://www.reddit.com/user/$user/submitted?sort=new
    pagenum=1
  else
    url=https://www.reddit.com/user/$user/submitted?sort=new\&count=$(expr 25 \* $pagenum)\&after=$token
    pagenum=$(expr $pagenum + 1)
  fi
  page=$(curl -s --cookie $cookie -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" $url)
  tokenold=$token
  token=$(echo $page | grep -oP 'after=\K[^"]+' | tail -n1)
  for i in $(echo $page | grep -oP 'data-url="\K[^"]+' | sort | uniq); do
    debecho "$countpls : $i"
    let countpls++
    if [[ $i == *"m.imgur.com"* ]]; then
      i=$(echo $i | sed -e 's/m\.//g')
    fi
    if [[ $i == *"www.imgur.com"* ]]; then
      i=$(echo $i | sed -e 's/www\.//g')
    fi
    if [[ ${i::5} == "http:" ]]; then
      i=https${i:4};
    fi
    if [[ ${i::4} == "http" ]]; then
      if [[ $i == *"imgur.com/a/"* ]] || [[ $i == *"imgur.com/gallery"* ]]; then
        i=$(echo $i | sed -e 's/\#.*//g')
        case $i in
          *"/a/"*)
            url=$(curl -s -D - -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" $i/zip -o /dev/null | grep Location | awk '{print $2}')
          ;;
          *"imgur.com/gallery"*)
            url=$(curl -s -D - -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" $i -o /dev/null | grep Location | awk '{print $2}')
            url=$(curl -s -D - -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" ${url%$'\r'}/zip -o /dev/null | grep Location | awk '{print $2}')
          ;;
        esac
        if [[ $url == *zip.imgur.com* ]]; then
          if ! [[ -d $user/albums/$(echo $i | awk -F "/" '{print $NF}') ]] && [[ -z $(cat $user/skip.txt 2>/dev/null | grep $(echo $i | awk -F "/" '{print $NF}')) ]]; then
            if ! [[ -d $user/albums/ ]]; then
              mkdir $user/albums/
            fi
            wget -q -O $user/albums/$(echo $i | awk -F "/" '{print $NF}').zip ${url%$'\r'}
            if [[ $? -eq 0 ]]; then
              webecho "album:" "$baseurl/$user/albums/$(echo $i | awk -F '/' '{print $NF}')"
              mkdir -p $user/albums/$(echo $i | awk -F "/" '{print $NF}')
              unzip -n -q $user/albums/$(echo $i | awk -F "/" '{print $NF}').zip -d $user/albums/$(echo $i | awk -F "/" '{print $NF}')
              rm $user/albums/$(echo $i | awk -F "/" '{print $NF}').zip
            else
              rm $user/albums/$(echo $i | awk -F "/" '{print $NF}').zip
              mkdir $user/albums/$(echo $i | awk -F "/" '{print $NF}')
              webecho "album:" "$baseurl/$user/albums/$(echo $i | awk -F '/' '{print $NF}')"
              for url in $(curl -s -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" $i | grep -oE i.imgur.com\/[a-zA-Z0-9]{7}.[a-zA-Z]{3\,4} | sort | uniq); do
                if [[ $(curl -s -D - ${url%$'\r'} -o /dev/null | grep Location | awk '{print $2}' | sed 's/\r$//') != *"removed.png"* ]]; then
                  wget -q https://$url --directory-prefix=$user/albums/$(echo $i | awk -F "/" '{print $NF}')
                fi
              done
            fi
            if [[ -z $(ls -A "$user/albums/$(echo $i | awk -F "/" '{print $NF}')") ]]; then
              echo "EMPTY ALBUM: $(echo $i | awk -F "/" '{print $NF}')" >> $user/$skipfn
              rmdir "$user/albums/$(echo $i | awk -F "/" '{print $NF}')"
            fi
          else
            debecho "Dupe Album: $i"
          fi
        else
          if ! [[ -d $user/images/ ]]; then
            mkdir $user/images/
          fi
          for url in $(curl -s -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" $i | grep -oE i.imgur.com\/[a-zA-Z0-9]{7}.[a-zA-Z]{3\,4} | sort | uniq); do
            if ! [[ -f $user/images/$(echo $url | awk -F "/" '{print $NF}') ]] && [[ $(cat $user/$skipfn 2>/dev/null | grep $(echo $url | awk -F "/" '{print $NF}')) == "" ]]; then
              wget -q https://$url --directory-prefix=$user/images/
              webecho "image:" "$baseurl/$user/images/$(echo $url | awk -F '/' '{print $NF}')"
              debecho "Image 1 i: $i"
            else
              debecho "Dupe image: $url"
            fi
          done
        fi
      elif ! [[ $i == *"i.imgur.com"* ]] && [[ $i == *"imgur.com"* ]]; then        
        if [[ $(ls $user/images/$(echo $i | awk -F "/" '{print $NF}').* 2>/dev/null) == "" ]] && [[ $(cat $user/$skipfn 2>/dev/null | grep $(echo $i | awk -F "/" '{print $NF}')) == "" ]]  && ! [[ -f $user/images/$(echo $i | awk -F "/" '{print $NF}') ]]; then
          if ! [[ -d $user/images/ ]]; then
            mkdir $user/images/
          fi
          url=$(curl -s -D - ${i%$'\r'} -o /dev/null | grep Location | awk '{print $2}' | sed 's/\r$//')
          if [[ $url != "" ]] && [[ $url != *"removed.png"* ]]; then
            wget -q $url --directory-prefix=$user/images/
            if [[ $? -eq 0 ]]; then
              if [[ $(file --brief --mime-encoding $user/images/$(echo $url | awk -F "/" '{print $NF}')) != "binary" ]]; then
                debecho "Deleting non binary file from $url"
                rm -f $user/images/$(echo $url | awk -F "/" '{print $NF}')
              else
                webecho "image:" "$baseurl/$user/images/$(echo $url | awk -F '/' '{print $NF}')"
                debecho "Image 2 i: $i"
              fi
            fi
          else
            for url in $(curl -s -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" $i | grep -oE i.imgur.com\/[a-zA-Z0-9]{7}.[a-zA-Z]{3\,4} | sort | uniq); do
              url=$(echo $url | sed -e 's/\?.*//g')
              if ! [[ -f $user/images/$(echo $url | awk -F "/" '{print $NF}') ]]; then
                if [[ $(curl -s -D - ${url%$'\r'} -o /dev/null | grep Location | awk '{print $2}' | sed 's/\r$//') != *"removed.png"* ]]; then
                  wget -q https://$url --directory-prefix=$user/images/
                  if [[ $(file --brief --mime-encoding $user/images/$(echo $url | awk -F "/" '{print $NF}')) != "binary" ]]; then
                    debecho "Deleting non binary file from $url"
                    rm -f $user/images/$(echo $url | awk -F "/" '{print $NF}')
                  else
                    webecho "image:" "$baseurl/$user/images/$(echo $url | awk -F '/' '{print $NF}')"
                    debecho "Image 3 i: $i"
                  fi
                fi
              fi
            done
          fi
        else
          debecho "Dupe image: $url"
        fi
      elif [[ $i == *"gfycat"* ]]; then
        url=https://$(echo $i | sed -e 's/thumbs\.//g' | sed -e 's/\-.*//g' | sed -e 's/\/gifs\/detail//g' | grep -oE gfycat.com\/[a-zA-Z]{\,})
        gfy=$(curl -s ${url%$'\r'} | grep -oP 'id=\"mp4Source\"\ src=\".+\"\ type=\"video/mp4\"' | awk '{print $2}' | tr -d \" | sed -e "s/src=//" | sed -e 's/thumbs\.//g')
        if [[ $gfy == "" ]]; then
          url=$(curl -s -D - ${url%$'\r'} -o /dev/null | grep Location | awk '{print $2}')
          if [[ $url != "" ]]; then
            gfy=$(curl -s ${url%$'\r'} | grep -oP 'id=\"mp4Source\"\ src=\".+\"\ type=\"video/mp4\"' | awk '{print $2}' | tr -d \" | sed -e "s/src=//" | sed -e 's/thumbs\.//g')
          fi
        fi
        if  [[ $gfy != "" ]] && ! [[ -f $user/videos/$(echo $gfy | awk -F "/" '{print $NF}') ]] && [[ $(cat $user/$skipfn 2>/dev/null | grep $(echo $gfy | awk -F "/" '{print $NF}')) == "" ]]; then
          if ! [[ -d $user/videos/ ]]; then
            mkdir $user/videos/
          fi
          wget -q $gfy --directory-prefix=$user/videos/
          if [[ -f $user/videos/$(echo $gfy | awk -F "/" '{print $NF}') ]]; then
            webecho "video:" "$baseurl/$user/videos/$(echo $gfy | awk -F '/' '{print $NF}')"
          fi
        else
          debecho "Dupe video: $url"
        fi
      elif [[ $i == *"reddituploads.com"* ]]; then
        url=$(echo $i | sed -e 's/amp\;//g')
        if [[ $(ls $user/images/$(echo $url | awk -F "/" '{print $NF}' | awk -F "?" '{print $1}').* 2>/dev/null) == "" ]] && [[ $(cat $user/$skipfn 2>/dev/null | grep $(echo $url | awk -F "/" '{print $NF}' | awk -F "?" '{print $1}')) == "" ]]; then
          if ! [[ -d $user/images/ ]]; then
            mkdir $user/images/
          fi
          curl -s -L --cookie /tmp/reddit -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" $url -o tempfile.temp
          if [[ -f tempfile.temp ]] && [[ $(file --brief --mime-encoding tempfile.temp) != "binary" ]]; then
            rm tempfile.temp
          elif [[ -f tempfile.temp ]]; then
            webecho "image:" "$baseurl/$user/images/$(echo $url | grep -oP '.com\/\K[^?]+').$(file --brief --mime-type tempfile.temp | awk -F '/' '{print $2}' | tr -d e)"
            mv tempfile.temp $user/images/$(echo $url | grep -oP '.com\/\K[^?]+').$(file --brief --mime-type tempfile.temp | awk -F "/" '{print $2}' | tr -d e)
            debecho "Image 4 i: $i"
          fi
        else
          debecho "Dupe image: $url"
        fi
      elif [[ $i == *"erome.com"* ]]; then
        urls=$(curl -s $i -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" | grep type=\'video | grep -oP 'src=\"\K[^"]+')
        urls=$(echo $urls | tr ' ' '\n' | sort -r | uniq -w 35)
        for url in $urls; do
          if [[ $url != "" ]] && ! [[ -f $user/videos/$(echo $url | awk -F "/" '{print $NF}') ]] && [[ $(cat $user/$skipfn 2>/dev/null | grep $(echo $url | awk -F "/" '{print $NF}')) == "" ]]; then
            if ! [[ -d $user/videos/ ]]; then
              mkdir $user/videos
            fi
            webecho "video:" "$baseurl/$user/videos/$(echo https:$url | awk -F '/' '{print $NF}')"
            wget -q https:$url --directory-prefix=$user/videos/
          else
            debecho "Dupe video: https:$url"
          fi
        done
      elif [[ $i == *"pornhub.com"* ]]; then
        url=https$(curl -s $i --cookie-jar /tmp/phub -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" | grep -oP 'videoUrl\"\:\"https\K[^"]+' | tr -d \\ 2>/dev/null | sort | tail -n1)
        if [[ $url != "https" ]] && ! [[ -f $user/videos/$(echo $url | awk -F "?" '{print $1}' | awk -F "/" '{print $NF}') ]] && [[ $(cat $user/$skipfn 2>/dev/null | grep $(echo $url | awk -F "?" '{print $1}' | awk -F "/" '{print $NF}')) == "" ]]; then
          if ! [[ -d $user/videos/ ]]; then
            mkdir $user/videos
          fi
          webecho "video:" "$baseurl/$user/videos/$(echo $url | awk -F '?' '{print $1}' | awk -F '/' '{print $NF}')"
          curl -s --cookie /tmp/phub -L -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" $url -o $user/videos/$(echo $url | awk -F "?" '{print $1}' | awk -F "/" '{print $NF}')
#          wget -q $url --directory-prefix=$user/videos/
          rm -rf /tmp/phub
        else
          debecho "Dupe video: $url"
        fi
      else
        url=$(echo $i | sed -e 's/\?.*//g')
        if [[ $(echo $url | awk -F "/" '{print $NF }') != "" ]] && ! [[ -f $user/images/$(echo $url | awk -F "/" '{print $NF}') ]] && [[ $(cat $user/$skipfn 2>/dev/null | grep $(echo $url | awk -F "/" '{print $NF}')) == "" ]]; then
          if [[ $url == *"gifv"* ]]; then
            for url in $(curl -s -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30" $i | grep -oE i.imgur.com\/[a-zA-Z0-9]{7}.[a-zA-Z0-9]{3\,4} | grep mp4 | sort | uniq -w19 | grep -v favicon); do
              if  [[ $url != "" ]] && ! [[ -f $user/videos/$(echo $url | awk -F "/" '{print $NF}') ]]; then
                if ! [[ -d $user/videos/ ]]; then
                  mkdir $user/videos/
                fi
                webecho "video:" "$baseurl/$user/videos/$(echo $url | awk -F '/' '{print $NF}')"
                wget -q https://$url --directory-prefix=$user/videos/
              else
                debecho "Dupe video: $url"
              fi
            done
          elif [[ $(curl -s -D - ${url%$'\r'} -o /dev/null | grep Location | awk '{print $2}' | sed 's/\r$//') != *"removed.png"* ]]; then
            wget -q $url --directory-prefix=$user/images/
            if [[ $? -eq 0 ]]; then
              if [[ $(file --brief --mime-encoding $user/images/$(echo $url | awk -F "/" '{print $NF}')) != "binary" ]]; then
                debecho "Deleting non binary file from $url"
                rm -f $user/images/$(echo $url | awk -F "/" '{print $NF}')
              else
                webecho "image:" "$baseurl/$user/images/$(echo $url | awk -F '/' '{print $NF}')"
                debecho "Image 5 i: $i"
              fi
            fi
          fi
        else
          debecho "Dupe image: $url"
        fi
      fi
    fi
  done
  if [[ $token == "" ]] || [[ $token == $tokenold ]]; then
    break
  fi
done
if [ -d $user/images ]; then
  curr=$(pwd)
  cd $user/images/
  debecho "$(pwd)"
  while read i; do
    if [[ "$i2" == $(echo "$i" | awk '{print $1}') ]]; then
      debecho "End Cleanup $i"
      echo "DUPED IMAGE: $i" >> ../$skipfn
      rm $(echo "$i" | awk '{print $2}')
    fi
    i2=$(echo "$i" | awk '{print $1}')
  done <<<"$(find -not -empty -type f -printf "%s\n" | sort -rn | uniq -d | xargs -I{} -n1 find -type f -size {}c -print0 | xargs -0 md5sum | sort)"
  cd $curr
fi
rm -rf $cookie
