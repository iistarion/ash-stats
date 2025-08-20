docker run -it --rm --name alp \
    -v /proc:"/host/proc:ro,rslave" \
    -v /sys:"/host/sys:ro,rslave" \
    -v /mnt/c:"/host/mnt/c:ro" \
    -v /mnt/e:"/host/mnt/e:ro" \
    -v ./stats.sh:/stats.sh \
    -v ./version.txt:/version.txt \
    alpine