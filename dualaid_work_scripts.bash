function convert_vdex_to_jar()
{
    #Need absolute path.
    local vdex_file="$1"
    local file_name_prefix
    local cdex_file_prefix
    local cdex_file_midfix="_classes"
    local cdex_file_suffix=".cdex"
    local cdex_new_file_suffix=".new"
    local jar_file_suffix=".jar"
    local output_file_num
    if [ -z $vdex_file ] ; then
        echo "Please check input file."
        return
    else
        file_name_prefix=${vdex_file%*.vdex}
    fi

    local vdex_extractor_result=`/home/zhiyuan/tools/convertVdexToJar/vdexExtractor -i $vdex_file`
    output_file_num="$(echo "$vdex_extractor_result" |grep "Dex files have been extracted in total" |awk '{print$2}')"
    cdex_file_prefix="$file_name_prefix$cdex_file_midfix"

    for ((i=1;i<=$output_file_num;i++)); do
        local need_handle_cdex
        if [ 1 -eq $i ]; then
            need_handle_cdex="$cdex_file_prefix$cdex_file_suffix"
        else
            need_handle_cdex="$cdex_file_prefix$i$cdex_file_suffix"
        fi
        local result=`/home/zhiyuan/tools/convertVdexToJar/9.0_linux-x86_64_shared/bin/compact_dex_converter $need_handle_cdex`

        local cdex_new_file="$need_handle_cdex$cdex_new_file_suffix"
        local result_jar_file="$need_handle_cdex$jar_file_suffix"
        mv $cdex_new_file $result_jar_file
        rm $need_handle_cdex
        echo "result_jar_file $result_jar_file convert success."
    done
}

function print_diff_perm_for_apps()
{
    #打印第二个参数包名 相对于 第一个参数包名 存在差异的权限，以第一个包名的权限状态为准
    local comm_pkg="$1"
    local dualaid_pkg="$2"
    local comm_dump_file="$PWD/$comm_pkg"
    local dualaid_dump_file="$PWD/$dualaid_pkg"

    local request_permission="requested permissions:";
    local install_permission="install permissions:";

    adb shell dumpsys package $comm_pkg > $comm_dump_file
    adb shell dumpsys package $dualaid_pkg > $dualaid_dump_file

    #requested permission first.
    awk 'BEGIN {key=1} /requested permissions:/,/install permissions:/ {print $0> "comm_requested" key ".txt"} /install permissions:/ {++key}' $comm_dump_file
    awk 'BEGIN {key=1} /requested permissions:/,/install permissions:/ {print $0> "dualaid_requested" key ".txt"} /install permissions:/ {++key}' $dualaid_dump_file

    echo "May Lack requeted permissions:"
    while read -r line
    do
	if [[ "$line" = "$request_permission" || "$line" = "$install_permission" ]]; then
	    continue
	fi
	local result=`cat dualaid_requested1.txt |grep "$line"`
	if [[ -z $result ]]; then
	    echo "    lack $line"
	fi
    done < comm_requested1.txt

    #install permissions second.
    awk 'BEGIN {key=1} /install permissions:/,/runtime permissions:/ {print $0> "comm_install" key ".txt"} /runtime permissions:/ {++key}' $comm_dump_file
    awk 'BEGIN {key=1} /install permissions:/,/runtime permissions:/ {print $0> "dualaid_install" key ".txt"} /runtime permissions:/ {++key}' $dualaid_dump_file

    echo "*************************************************************"
    echo "May Lack install permissions:"
    while read -r line
    do
        if [[ "$line" = "runtime permissions:" || "$line" = "$install_permission" || "$line" =~ "User 0" || "$line" =~ "gids" ]]; then
            continue
        fi
        local result=`cat dualaid_install1.txt |grep "$line"`
        if [[ -z $result ]]; then
            echo "    lack $line"
        fi
    done < comm_install1.txt

    #runtime permissions third.
    awk 'BEGIN {key=1} /runtime permissions:/,/enabledComponents:/ {print $0> "comm_runtime" key ".txt"} /enabledComponents:/ {++key}' $comm_dump_file
    awk 'BEGIN {key=1} /runtime permissions:/,/enabledComponents:/ {print $0> "dualaid_runtime" key ".txt"} /enabledComponents:/ {++key}' $dualaid_dump_file

    echo "*************************************************************"
    echo "May Lack runtime permissions:"
    while read -r line
        do
        if [[ "$line" = "runtime permissions:" || "$line" = "enabledComponents:" ]]; then
            continue
        fi
        local handle=`echo $line |awk '{print$1}'`
        local result=`cat dualaid_runtime1.txt |grep "$handle"`
        if [[ -z $result ]]; then
            echo "    lack $line"
        else
	    local dualaid_grant=`echo $result |awk '{print$2}'`
	    local comm_grant=`echo $line |awk '{print$2}'`
	    if [[ $dualaid_grant != $comm_grant ]]; then
		echo "diff ------------------------"
                echo -e "$comm_pkg: \t$line"
		echo -e "$dualaid_pkg: \t$result"
	    fi
	fi
    done < comm_runtime1.txt

    rm $comm_dump_file $dualaid_dump_file dualaid_requested1.txt comm_requested1.txt dualaid_install1.txt comm_install1.txt dualaid_runtime1.txt comm_runtime1.txt dualaid_runtime2.txt comm_runtime2.txt
}

