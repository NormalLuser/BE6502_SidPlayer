
NormalLuser here.
I found this code posted by realdmx and Modified Monty On the Run by Rob Hubbard.
Ben Eater needed something to show off the SID chip he added to his breadboard 6502.
This version runs stand-alone using the VIA for timing, and the $4800 mapping that Ben uses for the chip.

<https://github.com/NormalLuser/BE6502_SidPlayer/blob/main/Hubbard_Rob/MontyOnTheRun_BE6502.asm>

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
