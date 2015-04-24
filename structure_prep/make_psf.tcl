# Alex Moffett
# This script runs in the VMD tcl interpreter and takes a pdb file,
# generates a psf file with a water box and ions, converts the psf file 
# to CHARMM format (default is X-PLOR format for the VMD plugins Solvate
# and Autoionize), and then outputs prmtop and incprd files for use in the
# AMBER MD engine with CHAMBER.
# 
# Choose psf format ("charmm" will give CHARMM format, anything else will
# give X-PLOR format, suitable for use in NAMD. In this case, no prmtop
# or inpcrd files will be generated)
set psf_format charmm

#############################

cd /Users/Alexander/projects/BAK1/initial_structure_prep/apo/charmm

package require psfgen
package require solvate
package require autoionize

topology /Users/Alexander/toppar/top_all36_prot.rtf
topology /Users/Alexander/toppar/top_all36_na.rtf
topology /Users/Alexander/toppar/top_all36_cgenff.rtf
topology /Users/Alexander/toppar/stream/prot/toppar_all36_prot_na_combined.str

pdbalias atom ILE CD1 CD
pdbalias atom TPO 03P OT
pdbalias atom SEP 03P OT
pdbalias residue TPO THR
pdbalias residue SEP SER
pdbalias residue HIS HSE

foreach filename {3TL8A 3TL8D 3TL8G 3TL8H 3UIM 3ULZ} {
	resetpsf
	segment BAK1 {
		first ACE 
		last CT3	
		pdb ${filename}.pdb
	}
	segment ATP {pdb ATP_SRC.pdb}	
	patch SP2 BAK1:290
	patch THP2 BAK1:312
	patch THP2 BAK1:324
	patch THP2 BAK1:446
	patch THP2 BAK1:449
	patch THP2 BAK1:450
	patch THP2 BAK1:455        
	coordpdb ${filename}.pdb BAK1
        coordpdb ATP_SRC.pdb ATP
        guesscoord
	writepsf ${filename}_temp.psf
	writepdb ${filename}_temp.pdb
	solvate ${filename}_temp.psf ${filename}_temp.pdb -t 10 -o ${filename}_solv
	autoionize -psf ${filename}_solv.psf -pdb ${filename}_solv.pdb -sc .150 -o ${filename}_solv_ions
	rm ${filename}_temp.psf ${filename}_temp.pdb
	rm ${filename}_solv.psf ${filename}_solv.pdb
} 	

if {$psf_format == "charmm"} {
        foreach filename {3TL8A 3TL8D 3TL8G 3TL8H 3UIM 3ULZ} {
                resetpsf
                readpsf ${filename}_solv_ions.psf
                coordpdb ${filename}_solv_ions.pdb
                writepsf charmm ${filename}_solv_ions_charmm.psf
                writepdb ${filename}_solv_ions_charmm.pdb
                rm ${filename}_solv_ions.psf ${filename}_solv_ions.pdb
                }
        puts "CHARMM format"
        } else {
        puts "X-PLOR format"
}

set out [open box_dimensions.dat "w"]

foreach filename {3TL8-A 3TL8-D 3TL8-G 3TL8-H 3UIM 3ULZ} {
        mol load psf ${filename}_solv_ions_charmm.psf pdb ${filename}_solv_ions_charmm.pdb
        set water [atomselect top "water"]
        set boxdim [vecsub [lindex [measure minmax $water] 1] [lindex [measure minmax $water] 0]]
        puts $out "$boxdim"
}
close box_dimensions.dat

exit
