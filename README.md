
NormalLuser here.

Ben Eater said on a Patreon post that he needed something to show off the SID chip he added to his breadboard 6502 project.
I found this code posted by realdmx and Modified the 'Monty On the Run' .SID by Rob Hubbard.
This version runs stand-alone on the BE6502 using the VIA for timing, and the $4800 mapping that Ben uses for the chip.
If you have the VGA project connected and have the Vsync hooked up to the NMI pin of the CPU you can comment out the 'Setup60HzTimer' routine.
The 65c02 WAI command that is used responds to both IRQ and NMI, so no other changes are needed.

**** Fixed to use 50Hz timer instead of 60Hz!! ****

<https://github.com/NormalLuser/BE6502_SidPlayer/blob/main/MontyOnTheRun_BE6502.asm>

You can output a 'Woz' file for pasting into Woz Monitor with this:
vasm6502_oldstyle -Fwoz -dotdir -wdc02 -L Listing.txt MontyOnTheRun_BE6502.asm
<https://github.com/NormalLuser/BE6502_SidPlayer/blob/main/MontyOnTheRun_BE6502_Woz.txt>


See Ben's video about the SID and listen to the music at the end here:
<https://youtu.be/LSMQ3U1Thzw?si=Idimo2s8_pQ3cWlZ>



Enjoy!

Org info from realdmx: 
# C64_6581_SID_Players

## Original and reverse-engineered music players for the C64.

The SID 6581 (8580) is a mysterious beast.

In the olden days, every budding musician wanting to make it in the business had no other choice but to program their own music player.

The widely varying understanding of 6510 CPU and the 6581 soundchip, in combination with the artistic mind of the author, would yield a synergy of sound and style.

These are some sourcecode of the players used for many famous tunes.

They have been recovered or reverse-engineered by various people.

I've decided to publish these sources to be compatible with the ACME assembler, for no other reason than that's what I'm most familiar with.

Every assembly file should produce a .sid file which can be played with any modern SID player.

However, initially, some sourcecode might not build until it's cleaned up.

Feel free to pull request.
