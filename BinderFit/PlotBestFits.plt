# Show result of fitting tries that must be in a file whose name is to be given and the format:
#
#	Fitted Volumes   NDF  χ2  Q   	      υ ± dυ	    β_c ± dβ 	      B4(∞) ± dB
#
#####################################################################################################

#print filenames

do for [i=1:words(filenames)] {
    filename=word(filenames, i)
    set term wxt i
    stats filename using 4 name "A" nooutput
        
    #Make the plot in pdf where we are
    set terminal pdfcairo enhanced color font "Helvetica, 10"
    set output filename.".pdf"
    set xrange[-1:A_records/A_blocks+1]
    set yrange[0:1]
    set label 1 "Q=50% " at A_records/A_blocks+1,0.25 right
    set label 2 "{/Symbol c}2=1 " at A_records/A_blocks+1,0.1 right
    set xtics nomirror rotate by -45
    set title system("TMP=".filename."; echo $TMP | sed 's/_/ /g'")
    set key font ",10"
    plot 0.5 lc 9 lw 0.5 notitle, 0.63 lc 9 lw 0.5 notitle, 0.33 lc 9 lw 0.5 notitle, \
        filename index 0 u 0:5:($6/sqrt($3)):xticlabel(1) w e lt 1 title "{/Symbol n}  ", \
        filename index 0 u 0:($4/1000+0.2) lt 9 lc 3 ps 0.5 notitle, \
        filename index 0 u 0:($3/10) lt 7 lc 4 ps 0.5 notitle, \
        0.25 lt 0 notitle, 0.1 lt 0 notitle, \
        1/0 lt 9 lc 3 lw 0.25 with points title "Q in [0.2 ; 0.3]", \
        1/0 lt 7 lc 4 lw 0.25 with points title "{/Symbol c}2/10"
    set terminal wxt i

    #Here I correct the error dividing by the square root of the chi2
    set label 2 "χ2=1 " at A_records/A_blocks+1,0.1 right
    plot 0.5 lc 9 lw 0.5 notitle, 0.63 lc 9 lw 0.5 notitle, 0.33 lc 9 lw 0.5 notitle, \
        filename index 0 u 0:5:($6/sqrt($3)):xticlabel(1) w e lt 1 title "ν", \
        filename index 0 u 0:($4/1000+0.2) lt 9 lc 3 notitle, \
        filename index 0 u 0:($3/10) lt 7 lc 4 notitle, \
        0.25 lt 0 notitle, 0.1 lt 0 notitle, \
        1/0 lt 9 lc 3 with points title "Q in [0.2 ; 0.3]", \
        1/0 lt 7 lc 4 with points title "χ2/10"

    #Crucial for the following call to stats filename, since it uses the x/yrange currently set
    set autoscale x
    set autoscale y
    unset label 1
    unset label 2
}

pause -1
q()
