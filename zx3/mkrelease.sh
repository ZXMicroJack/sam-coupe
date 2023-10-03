#!/bin/bash
rm -rf release
mkdir release
cp ./samcoupe.runs/impl_3/samcoupezx3.bit ./release/samcoupezx3_a200t.bit
cp ./samcoupe.runs/impl_1/samcoupezx3.bit ./release/samcoupezx3_a35t.bit
cp ./samcoupe.runs/impl_2/samcoupezx3.bit ./release/samcoupezx3_a100t.bit
~/zx3/zx3ctrl/tools/Bit2Bin ./samcoupe.runs/impl_3/samcoupezx3.bit ./release/samcoupezx3_a200t.zx3
~/zx3/zx3ctrl/tools/Bit2Bin ./samcoupe.runs/impl_1/samcoupezx3.bit ./release/samcoupezx3_a35t.zx3
~/zx3/zx3ctrl/tools/Bit2Bin ./samcoupe.runs/impl_2/samcoupezx3.bit ./release/samcoupezx3_a100t.zx3
cp ../README.txt release
