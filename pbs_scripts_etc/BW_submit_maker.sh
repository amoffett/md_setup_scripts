#!/bin/bash

TYPE="xk"
NNODE=1
ALLO="jt3"
QUE="low"
REPS=1
ROUND=1
STRUC=0
INPUT=0
OUTPUT=0
WT="23:30:00"
SEP=False

usage() { echo "
        Usage: $0
        
        This script will take the location of AMBER inpcrd/rst and prmtop files to be used as starting
        files as an input and produce PBS scripts to run production simulations on Blue Waters. Run
        out of an empty simulation directory. All paths required as input should be absolute paths. 
        Corresponding inpcrd/rst and prmtop files should have the same name preceding the extension and
        only files to be used for this setup should be included in the structure/topology directory.
        
        To use this script, in short:
                1) Make a new directory to run simulations out of and enter that directory.
                2) Use bwsub in that directory with all the required options and any other optional flags.
                3) Go to the submit_scripts directory and enter \"bash round_1_submit.sh\".
                4) This should submit the first round of jobs, and once the first round is done, do the
                same thing for \"round_2_submit.sh\", and so on.

        [To make a directory in the simulation directory, just use \$(pwd)/<NAME>] 

        -o string (full path to output directory to be created) REQUIRED 
        -c Boolean (create seperate subdirectories for each system within the output directory?) [Default: False]
        -i string (full path to AMBER input file) REQUIRED 
        -s string (full path to structure and topology directory) REQUIRED
        -t "xe" or "xk" (node type) [Default: "xk"]
        -n integer (number of nodes to use) [Default: 1] 
        -a three letter string (Blue Waters allocation name) [Default: "jt3"] 
        -q "low" or "normal" or "high" (queue priority to use) [Default: "low"]
        -r integer (number of replicates to produce for each starting structure) [Default: 1] 
        -d integer (number of rounds of MD to set up) [Default: 1]
        -w three sets of two integers separated by colons (walltime) [Default: "23:30:30"]
        " 1>&2; exit 1; }

while getopts ":s:c:i:o:t:n:a:q:r:d:w:h" opt; do
        case "${opt}" in
                s)
                        if [[ $OPTARG =~ ^[^[:space:]]*$ && $OPTARG =~ ^[/]{1}.*$ ]]; then
                                STRUC=$OPTARG
                        else
                                echo "-s requires an argument and must specify a full path"
                                usage
                                exit 1
                        fi
                        ;;
                c)
                        if [[ $OPTARG == True || $OPTARG == False ]]; then
                                SEP=$OPTARG
                        else
                                usage
                                exit 1
                        fi
                        ;;
                i)
                        if [[ $OPTARG =~ ^[^[:space:]]*$ && $OPTARG =~ ^[/]{1}.*$ ]]; then
                                INPUT=$OPTARG
                        else
                                echo "-i requires an argument and must specify a full path"
                                usage
                                exit 1
                        fi
                        ;;
                o)
                        if [[ $OPTARG =~ ^[^[:space:]]*$ && $OPTARG =~ ^[/]{1}.*$ ]]; then
                                OUTPUT=$OPTARG
                        else
                                echo "-o requires an argument and must specify a full path"
                                usage
                                exit 1
                        fi
                        ;;
                t)
                        if [[ $OPTARG == "xe" || $OPTARG == "xk" ]]; then
                                TYPE=$OPTARG
                        else
                                usage
                                exit 1
                        fi
                        ;;
                n)
                        if [[ $OPTARG =~ ^[0-9]+$ && $OPTARG -gt 0 ]]; then
                                NNODE=$OPTARG
                        else
                                usage
                                exit 1
                        fi
                        ;;
                a)
                        if [[ $OPTARG =~ ^[[:alnum:]_]{3}$ ]]; then
                                ALLO=$OPTARG
                        else
                                usage
                                exit 1
                        fi
                        ;;
                q)
                        if [[ $OPTARG == "low" || $OPTARG == "normal" || $OPTARG == "high" ]]; then
                                QUE=$OPTARG
                        else
                                usage
                                exit 1
                        fi
                        ;;
                r)
                        if [[ $OPTARG =~ ^[0-9]+$ && $OPTARG -gt 0 ]]; then
                                REPS=$OPTARG
                        else
                                usage
                                exit 1
                        fi
                        ;;

                d)
                        if [[ $OPTARG =~ ^[0-9]+$ && $OPTARG -gt 0 ]]; then
                                ROUND=$OPTARG
                        else
                                usage
                                exit 1
                        fi
                        ;;
                w)
                        if [[ $OPTARG =~ ^[0-9]{2}\:[0-9]{2}\:[0-9]{2}$ ]]; then
                                WT=$OPTARG
                        else
                                usage
                                exit 1
                        fi
                        ;;
                h)
                        usage
                        exit 1
                        ;;
                \?)
                        echo "Invalid option -$OPTARG" >&2
                        usage
                        exit 1
                        ;;
        esac
done

if [[ $STRUC == 0 ]]; then
        echo "-s requires an argument"
        usage
        exit 1
elif [[ $OUTPUT == 0 ]]; then
        echo "-o requires an argument"
        usage
        exit 1
elif [[ $INPUT == 0 ]]; then
        echo "-i requires an argument"
        usage
        exit 1
fi

if [[ $TYPE == "xk" ]]; then
        ppn=1
        amber="cuda"
else
        ppn=32
        amber="MPI"
fi

totprocs=$(($ppn*$NNODE))

dir=$(pwd)

cd $dir
mkdir $OUTPUT
mkdir pbs_scripts
mkdir submit_scripts
cd pbs_scripts

count=0
for pathway in $(ls ${STRUC}/*.[r,i][s,n][t,p]*); do
        file=$(echo $pathway | rev | cut -d "/" -f1 | rev)
        if [[ $file =~ ^.*inpcrd$ || $file =~ ^.*rst$  ]]; then
                name="$(echo $file | rev | cut -d "." -f2- | rev)"
                parm="${name}.prmtop"
        else
                echo "Error: only AMBER rst and inpcrd files are supported"
                exit 1
        fi
        if [[ $SEP == True ]]; then
                cd $OUTPUT
                mkdir $OUTPUT/${name}
                OUT="$OUTPUT/${name}"
        else
                OUT="$OUTPUT"
        fi
        for run in $(seq 1 $ROUND); do
                for rep in $(seq 1 $REPS); do
                        cd ${dir}/pbs_scripts
                        echo "#!/bin/bash" > round_${run}_rep_${rep}_${name}.pbs
                        echo "#PBS -l nodes=${NNODE}:ppn=${ppn}:${TYPE}" >> round_${run}_rep_${rep}_${name}.pbs
                        echo "#PBS -l walltime=$WT" >> round_${run}_rep_${rep}_${name}.pbs
                        echo "#PBS -N round_${run}_rep_${rep}_${name}" >> round_${run}_rep_${rep}_${name}.pbs
                        echo "#PBS -e round_${run}_rep_${rep}_${name}.err" >> round_${run}_rep_${rep}_${name}.pbs
                        echo "#PBS -o round_${run}_rep_${rep}_${name}.out" >> round_${run}_rep_${rep}_${name}.pbs
                        echo "#PBS -q ${QUE}" >> round_${run}_rep_${rep}_${name}.pbs
                        echo "#PBS -A ${ALLO}" >> round_${run}_rep_${rep}_${name}.pbs
                        echo "" >> round_${run}_rep_${rep}_${name}.pbs
                        echo "cd ${dir}/pbs_scripts" >> round_${run}_rep_${rep}_${name}.pbs
                        echo "" >> round_${run}_rep_${rep}_${name}.pbs
                        if [[ $TYPE == "xk" ]]; then
                                echo 'export AMBERHOME=/projects/sciteam/jt3/amber14cuda' >> round_${run}_rep_${rep}_${name}.pbs
                                echo 'export PATH=/projects/sciteam/jt3/amber14cuda/bin/:$PATH' >> round_${run}_rep_${rep}_${name}.pbs
                        else
                                echo 'export AMBERHOME=/projects/sciteam/jt3/amber14' >> round_${run}_rep_${rep}_${name}.pbs
                                echo 'export PATH=/projects/sciteam/jt3/amber14/bin/:$PATH' >> round_${run}_rep_${rep}_${name}.pbs
                        fi
                        echo 'export CUDA_HOME=/opt/nvidia/cudatoolkit6.5/6.5.14-1.0502.9613.6.1' >> round_${run}_rep_${rep}_${name}.pbs
                        echo 'export LD_LIBRARY_PATH=/opt/nvidia/cudatoolkit6.5/6.5.14-1.0502.9613.6.1/lib:/opt/nvidia/cudatoolkit6.5/6.5.14-1.0502.9613.6.1/lib64:$LD_LIBRARY_PATH' >> round_${run}_rep_${rep}_${name}.pbs
                        echo "" >> round_${run}_rep_${rep}_${name}.pbs
                        prev=$(($run - 1))
                        if [[ $run = 1 ]]; then
                                echo "aprun -n ${totprocs} -N ${ppn} pmemd.${amber} -O -p ${STRUC}/${parm} -c ${STRUC}/${file} -i ${INPUT} -o ${OUT}/round_${run}_rep_${rep}_${name}.out -x ${OUT}/round_${run}_rep_${rep}_${name}.mdcrd -r ${OUT}/round_${run}_rep_${rep}_${name}.rst" >> round_${run}_rep_${rep}_${name}.pbs                                                                                                                                                     1,8           Top
			else
                                echo "aprun -n ${totprocs} -N ${ppn} pmemd.${amber} -O -p ${STRUC}/${parm} -c ${OUT}/round_${prev}_rep_${rep}_${name}.rst -i ${INPUT} -o ${OUT}/round_${run}_rep_${rep}_${name}.out -x ${OUT}/round_${run}_rep_${rep}_${name}.mdcrd -r ${OUT}/round_${run}_rep_${rep}_${name}.rst" >> round_${run}_rep_${rep}_${name}.pbs
                        fi
                        cd ${dir}/submit_scripts
                        if [[ $rep == 1 && $count == 0 ]]; then
                                echo "#!/bin/bash" >> round_${run}_submit.sh
                                echo "cd ${dir}/pbs_scripts" >> round_${run}_submit.sh
                        fi
                        echo "JOB""=\"qsub ""round_${run}_rep_${rep}_${name}.pbs\"" >> round_${run}_submit.sh
                        echo '$JOB' >> round_${run}_submit.sh
                done
                cd ${dir}/submit_scripts
                echo "cd ${dir}/submit_scripts" >> round_${run}_submit.sh
                echo "echo \"ROUND ${run} SYSTEM ${name}\" >> job_submission.log" >> round_${run}_submit.sh
                echo "cd ${dir}/pbs_scripts" >> round_${run}_submit.sh
        done
        count=$(($count + 1))
done


