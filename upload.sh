#!/bin/bash

set -e

# see tasmota/tasmota_xdrv_driver/xdrv_50_filesystem.ino
# shellcheck disable=SC1102,SC2215
MAX_FNAME_LEN=45

base_url='http://tasmota-thermostat'
curl_opts=(--silent)
#curl_opts=(-vv -i)

files=(
    display.ini
    pages.jsonl
    *.be
    assets/*.font
)
#files=(lv_thermostat_card.be)

tooldir="$(dirname "$0")"

restart()
{
    curl "${curl_opts[@]}" \
        --data-urlencode "cmnd=restart 1" \
        "${base_url}/cm"
}

download_file()
{
    local fn="$1"
    curl "${curl_opts[@]}" \
        --data-urlencode "download=/$fn" \
        "${base_url}/ufsd"
}

upload_file()
{
    local fn="$1"
    local fsz="$2"
    curl "${curl_opts[@]}" "${base_url}/ufsu?fsz=$fsz" --form "ufsu=@-;filename=$fn" | grep -q 'Successful'
}

read_rootdir()
{
    # need this to persuade the server that the subsequent upload is going to be a UPL_UFSFILE type
    # see https://github.com/arendst/Tasmota/discussions/20171#discussioncomment-11735457
    curl "${curl_opts[@]}" "${base_url}/ufsd" >/dev/null
}

run_berry_command()
{
    local cmd="$1"
    curl "${curl_opts[@]}" \
        --data-urlencode "c2=0" \
        --data-urlencode "c1=$cmd" \
        "${base_url}/bc" | sed '1s/.*\x01//'   # cut off command prefix
}

delete_file()
{
    local fn="$1"
    curl "${curl_opts[@]}" \
        --data-urlencode "delete=/$fn" \
        "${base_url}/ufsd" >/dev/null
}

any_changes=''
any_errors=''

for f in "${files[@]}"
do
    fname="$(basename "$f")"
    if [ ${#fname} -gt "${MAX_FNAME_LEN}" ]
    then
        echo "File name '$fname' is too long (actual: ${#fname}, allowed: ${MAX_FNAME_LEN})"
    elif [ -f "$f" ]
    then
        if [[ $f == *.be ]]
        then
            new_content="$("$tooldir"/strip-berry-code.py < "$f")"
            if diff -q <(download_file "$fname") <(echo -n "${new_content}") >/dev/null
            then
                echo "File '$fname' unchanged"
            else
                #diff -u <(echo -n "${old_content}"|hexdump -C) <(echo -n "${new_content}"|hexdump -C) || : # >/dev/null
                echo "File '$fname' changed"
                echo -n "    uploading "
                read_rootdir
                if echo -n "${new_content}" | upload_file "$fname" ${#new_content}
                then
                    echo "successful"
                    echo -n "    compiling "
                    any_changes='x'
                    res="$(run_berry_command "tasmota.compile(\"$fname\")")"
                    if [ "$(echo "$res" | xargs)" = 'true' ]
                    then
                        echo "successful"
                        # delete compiled file
                        #delete_file "/${fname}c"
                    else
                        echo "with errors:"
                        echo "'$res'" | sed 's/^/\t/'
                        any_errors='x'
                    fi
                else
                    echo "failed"
                    any_errors='x'
                fi
            fi
        else
            if diff -q <(download_file "$fname") "$f" >/dev/null
            then
                echo "File '$fname' unchanged"
            else
                echo -n "File '$fname' changed -> uploading "
                read_rootdir
                if upload_file "$fname" "$(stat -c '%s' "$f")" < "$f"
                then
                    echo "successful"
                    any_changes='x'
                else
                    echo "failed"
                    any_errors='x'
                fi
            fi
        fi
    else
        echo "Local file '$f' does not exist"
    fi
done

if [ "${any_changes}" ] && [ -z "${any_errors}" ]
then
    restart
fi
