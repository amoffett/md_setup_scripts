#!/bin/bash/
#
# Script to set up runs on Blue Waters for X hours using pmemd (a ~40,000 atom system	
# gets ~40ns running pmemd.cuda on a single GPU).
# In the base directory, it creates a directory for each system, and makes PBS files
# for each replicate system and each consecutive run of each replicate.
# Bash scripts are created in a separate directory, one for each day's worth of
# submissions across all systems and replicates. 
#
# The base directory for n systems with y replicates for each system 
# running for x runs will then look like this:
#
#	   		       	     |--|submit_scripts/ -- submit_day1,... submit_dayx
#	   		       	     |
# basedir/ --|SIMULATION_SET_NAME/ --|--|SYSTEM1/ -- SYSTEM1.prmtop, SYSTEM1.in, SYSTEM1_1_1.pbs, ...SYSTEM1_x_y.pbs   
#	   	                     |
#	   		             |--|SYSTEM2/ -- SYSTEM2.prmtop, SYSTEM2.in, SYSTEM2_1_1.pbs, ...SYSTEM2_x_y.pbs
#	   		             ...
#	   		             |--|SYSTEMn/ -- SYSTEMn.prmtop, SYSTEMn.in, SYSTEMn_1_1.pbs, ...SYSTEMn_x_y.pbs
#
##########################################################################################
# **IMPORTANT: Assumes you have put prmtop files in your base directory ($basedir) named #
# "${sysnames[$sys]}_${prmname}.prmtop" for each system, and have already run            #
# minimization with the restart files named						 #
# "${name}_min_${sysnames[$sys]}_${prmname}.rst" in the scratch output directory         #
# ($outdir).          									 #
# For example:										 #
#  minimization restart: /u/sciteam/moffett/scratch/output/AMD_min_3UIM_ATP.rst 	 #
#  prmtop file: /u/sciteam/moffett/BAK1_aMD/initial_aMD/3UIM_ATP.prmtop 		 #
##########################################################################################
#
# Use GPU
GPU=1

# Use MPI 
MPI=0

# Number of processors to use per node (each node has one GPU)
procs=1

# Number of nodes to use
node=1

# BW allocation code
project=jt3

# Walltime for each job
time="24:00:00"

# Specify queue priority
queue=normal

# Simulation name
name=AMD

# Total time in microseconds
tottime=2

# Number of different systems to run
numsys=6

# Number of replicates / conditions per system
replicate=10

# Names of the systems
sysnames=(3TL8A 3TL8D 3TL8G 3TL8H 3UIM 3ULZ)

# Set the base directory to run out of and make subdirectories in
basedir="/u/sciteam/moffett/BAK1_aMD/"

# Name the simulation directory
simdir="AMD_runs"

# Set the output directory
outdir="/u/sciteam/moffett/scratch/output/BAK1_AMD/"

# Set the portionof the name of your prmtop files following
# the system name
prmname=ATP

##########################################################################################

if [[ ($GPU=1) && ($MPI=0) ]]; then
	type="xk"
	ambertype=".cuda"
elif [[ ($GPU=1) && ($MPI=1) ]]; then 
	type="xk"
	ambertype=".MPI.CUDA"
elif [[ ($GPU=0) && ($MPI=1) ]]; then
	type="xe"
	ambertype=".MPI"
elif [[ ($GPU=0) && ($MPI=0) ]]; then
	type="xe"
	ambertype=""
fi

runs=$(bc<<<"scale=2;(${tottime}*1000)/(40)")

numpes=$(expr $procs * $node)

cd ${basedir}
mkdir ${simdir}
mv *.prmtop ${simdir}/
mv *.in ${simdir}/

for sys in $(seq 0 $(expr $numsys - 1)); do
	cd ${basedir}${simdir}
	mkdir ${sysnames[$sys]}/
	mv ${sysnames[$sys]}*.prmtop ${sysnames[$sys]}/
	mv ${sysnames[$sys]}.in ${sysnames[$sys]}/
	cd ${sysnames[$sys]}/
	for rep in $(seq 1 $replicate); do
		for run in $(seq 1 $runs); do
			if [ $run = 1 ]; then
				crd=min
				repmin=""
			else
				crd=$(expr $run - 1)
				repmin="${rep}_"
			fi
			echo "#!/bin/bash" > ${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs
			echo "#PBS -l nodes=${node}:ppn=${procs}:${type}" >> ${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs
			echo "#PBS -l walltime=${time}" >> ${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs
			echo "#PBS -N ${sysnames[$sys]}_${name}_${rep}_${run}" >> ${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs
			echo "#PBS -e ${sysnames[$sys]}_${name}_${rep}_${run}.err" >> ${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs
			echo "#PBS -o ${sysnames[$sys]}_${name}_${rep}_${run}.out" >> ${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs
			echo "#PBS -q ${queue}" >> ${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs
			echo "#PBS -A ${project} >> ${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs
			echo "" >> ${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs
			echo "cd ${basedir}" >> ${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs
			echo "aprun -n ${numpes} -N ${procs} pmemd${ambertype} -O -p ${sysnames[$sys]}_${prmname}.prmtop -c ${outdir}${name}_${crd}_${sysnames[$sys]}_${repmin}${prmname}.rst -i ${sysnames[$sys]}.in -o ${outdir}${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.out -x ${outdir}${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.mdcrd -r ${outdir}${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.rst" >> ${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs
		done
	done
done

cd ${basedir}${simdir}
mkdir submit_scripts
cd submit_scripts

for run in $(seq 1 $runs); do
	loop=0
	echo "#!/bin/bash" > day_${run}_submit
	for sys in $(seq 0 $(expr $numsys - 1)); do
        	for rep in $(seq 1 $replicate); do
			loop=$(expr $loop + 1)
			echo "cd ${basedir}${simdir}/${sysnames[$sys]}" >> day_${run}_submit
			echo 'JOB_'"$loop"'="qsub '"${name}_${run}_${sysnames[$sys]}_${rep}_${prmname}.pbs\"" >> day_${run}_submit
		done
	done
done

