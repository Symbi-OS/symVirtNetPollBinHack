sudo echo "Chill for 1 second"
sleep 1


echo collecting napi now
sudo /usr/share/bcc/tools/argdist -d 1 -i 1 -C 'p::virtnet_poll(void *napi, int budget):void*:napi' | tee napi_out


# Deal with napi
NUM_NAPIS=$(cat napi_out | grep 'napi =' | wc -l)

if [[ $NUM_NAPIS != 1 ]]; then
	echo dont know what to do with $NUM_NAPIS NAPIS
	exit
fi

NAPI_ADDR=$(cat napi_out | grep 'napi =' | cut -d '=' -f 2 | xargs printf "%lx")

# Deal with vqs
echo collecting vqs now
sudo /usr/share/bcc/tools/argdist -d 1 -i 1 -C 'p::virtqueue_disable_cb(void *vq):void*:vq' | tee vq_out


NUM_VQS=$(cat vq_out | grep 'vq =' | wc -l)

VQ1=0
VQ2=0
VQ3=0

# Assuming they're listed in increasing order and we care about the 2 biggest
if [[ $NUM_VQS == 2 ]]; then
	VQ1=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 2 | tail -n 1 | xargs printf "%lx")
	VQ2=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 1 | tail -n 1 | xargs printf "%lx")
elif [[ $NUM_VQS == 3 ]]; then
	VQ1=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 3 | tail -n 1 | xargs printf "%lx")
	VQ2=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 2 | tail -n 1 | xargs printf "%lx")
	VQ3=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 2 | tail -n 1 | xargs printf "%lx")
else
	echo dont know what to do with $NUM_VQS vqs... bailing
	exit
fi

echo
echo NAPI: $NAPI_ADDR
echo VQ1: $VQ1
echo VQ2: $VQ2
echo probably ignore VQ3: $VQ3
echo

echo run symbiote?
echo run taskset -c 1 ./poller -d -n $NAPI_ADDR -v $VQ1 -v $VQ2 -c -i -1 -s 10

echo "Kick it off? [Y,n]"
read input
if [[ $input == "Y" || $input == "y" ]]; then
	taskset -c 1 ~/Symbi-OS/Apps/examples/sym_poll/poller -d -n $NAPI_ADDR -v $VQ1 -v $VQ2 -c -i -1 -s 10
else
        echo "Didn't start symbiote"
fi

