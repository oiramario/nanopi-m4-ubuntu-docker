#set -x
cd sources
sub_dirs=`ls -d *`

for dir in $sub_dirs
do
    package=../packages/$dir.tar
    echo $dir
    echo Packaging ...
    tar --exclude=.git -cf $package $i
    echo compressing ...
    xz --compress --extreme --threads=0 $package
    echo "Done."
    echo
done
