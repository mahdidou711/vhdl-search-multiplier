restart -f
add wave /*

# Horloge (periode = 50 ps/ns selon ton affichage ModelSim)
force clk 0 0, 1 25 -repeat 50

# Initialisation
force reset 0
force start 0
force A_in 16#0D
force B_in 16#0B

# Reset actif
run 100

# Relacher reset
force reset 1
run 100

# Lancer la multiplication
force start 1
run 600

# Relacher start (retour vers IDLE apres DONE)
force start 0
run 200