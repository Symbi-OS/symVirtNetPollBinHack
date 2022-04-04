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

# NAPI_ADDR=$(cat napi_out | grep 'napi =' | cut -d '=' -f 2 | xargs printf "%lx")
NAPI_ADDR_DEC=$(cat napi_out | grep 'napi =' | cut -d '=' -f 2)
NAPI_ADDR=$(printf "%lx" $NAPI_ADDR_DEC )

# Deal with vqs
echo collecting vqs now
sudo /usr/share/bcc/tools/argdist -d 2 -i 2 -C 'p::virtqueue_disable_cb(void *vq):void*:vq' | tee vq_out

NUM_VQS=$(cat vq_out | grep 'vq =' | wc -l)

VQ1=0
VQ2=0
VQ3=0

# Assuming they're listed in increasing order and we care about the 2 biggest
if [[ $NUM_VQS == 2 ]]; then
	  # VQ1=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 2 | tail -n 1 | xargs printf "%lx")
	  # VQ2=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 1 | tail -n 1 | xargs printf "%lx")
    VQ1_DEC=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 2 | tail -n 1)
    VQ2_DEC=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 1 | tail -n 1)

    VQ1=$(printf "%lx" $VQ1_DEC)
    VQ2=$(printf "%lx" $VQ2_DEC)

elif [[ $NUM_VQS == 3 ]]; then
	  # VQ1=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 3 | tail -n 1 | xargs printf "%lx")
	  # VQ2=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 2 | tail -n 1 | xargs printf "%lx")
	  # VQ3=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 1 | tail -n 1 | xargs printf "%lx")
	  VQ1_DEC=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 3 | tail -n 1 )
	  VQ2_DEC=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 2 | tail -n 1 )
	  VQ3_DEC=$(cat vq_out | grep 'vq =' | cut -d '=' -f 2 | head -n 1 | tail -n 1 )

    VQ1=$(printf "%lx" $VQ1_DEC)
    VQ2=$(printf "%lx" $VQ2_DEC)
    VQ3=$(printf "%lx" $VQ3_DEC)

else
	echo dont know what to do with $NUM_VQS vqs... bailing
	exit
fi

# Printout for user
echo
echo NAPI: 0x$NAPI_ADDR    dec: $NAPI_ADDR_DEC
echo VQ1:   0x$VQ1    dec: $VQ1_DEC
echo VQ2:   0x$VQ2    dec: $VQ2_DEC
echo
echo probably ignore VQ3: 0x$VQ3    dec: $VQ3_DEC
echo

rm napi_out vq_out

POLLER=../../Apps/examples/sym_poll/poller
TASKSET="taskset -c 1"

# Key for user
echo run symbiote?
echo d\)  $TASKSET $POLLER -d -n $NAPI_ADDR -v $VQ1 -v $VQ2
echo e\)  $TASKSET $POLLER -e -v $VQ1 -v $VQ2
echo p\)  $TASKSET $POLLER -p -n $NAPI_ADDR
echo c\)  $TASKSET $POLLER -c -n $NAPI_ADDR -i 100 -s 100000
echo dc\) $TASKSET $POLLER -d -n $NAPI_ADDR -v $VQ1 -v $VQ2 -c -i 100 -s 100000
echo x\)  exit

# User cmdline control
while true
do
    echo -n type any char from the table above:
    read input
    case $input in
        d)
            echo diable vqs
            $TASKSET $POLLER -d -n $NAPI_ADDR -v $VQ1 -v $VQ2
            ;;
        e)
            echo enable vq
            echo e\)  $TASKSET $POLLER -e -v $VQ1 -v $VQ2
            ;;
        p)
            echo poll once
            $TASKSET $POLLER -d -n $NAPI_ADDR -v $VQ1 -v $VQ2 -p
            ;;
        c)
            echo poll continuously
	          $TASKSET $POLLER -n $NAPI_ADDR -c -i -1 -s 10
            ;;
        dc)
            echo disable then poll continuously
	          $TASKSET $POLLER -d -n $NAPI_ADDR -v $VQ1 -v $VQ2 -c -i -1 -s 10
            ;;
        x)
            echo exit case
            exit
            ;;
        *)
            echo unexpected input $input, exiting
            exit
            ;;
    esac
done

echo out of loop
exit
