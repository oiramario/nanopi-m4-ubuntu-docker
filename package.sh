#set -x
cd sources
sub_dirs=`ls -d *`

for dir in $sub_dirs
do
    package=../packages/$dir.tar
    echo -e "\e[35m $dir \e[0m"
    echo Packaging ...
    tar --exclude=.git -cf $package $i
    echo compressing ...
    xz -zef --threads=0 $package
    echo -e "\e[36m $dir \e[0m"
    echo
done
