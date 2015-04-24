#!/bin/bash

# /Applications/VMD\ 1.9.2.app/Contents/MacOS/startup.command -dispdev text -e make_psf.tcl 

linenum=0

for filename in 3TL8-A 3TL8-D 3TL8-G 3TL8-H 3UIM 3ULZ; do
	linenum=$(expr $linenum + 1)
	boxdim=$(head -$linenum box_dimensions.dat | tail -1)
	chamber -top /Users/Alexander/toppar/top_all36_prot.rtf -param /Users/Alexander/toppar/par_all36_prot.prm -str /Users/Alexander/toppar/top_all36_na.rtf /Users/Alexander/toppar/par_all36_na.prm /Users/Alexander/toppar/stream/prot/toppar_all36_prot_na_combined.str /Users/Alexander/toppar/toppar_water_ions.str -psf ${filename}_solv_ions_charmm.psf -crd ${filename}_solv_ions_charmm.pdb -p ${filename}.prmtop -inpcrd ${filename}.inpcrd -cmap -vmd -box $boxdim
done
 
