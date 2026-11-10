"""Short synthesized material hits saved as editable WAV assets; stdlib only."""
import math, random, struct, wave
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'assets/audio/impact'
root.mkdir(parents=True,exist_ok=True)
rate=44100
for name,base in [('pony',145),('pumpkin',78),('slime',190),('sugar_crack',2200)]:
    rng=random.Random(417)
    duration=.18 if name=='sugar_crack' else .32
    values=[];low=0.;previous=0.
    for i in range(int(duration*rate)):
        t=i/rate;n=rng.uniform(-1,1);low=.84*low+.16*n
        if name=='sugar_crack':
            sample=(n-previous)*.38*math.exp(-t*32)+.16*math.sin(math.tau*base*t)*math.exp(-t*46)
        elif name=='slime':
            phase=math.tau*(base*t-120*t*t)
            sample=.65*math.sin(phase)*math.exp(-t*15)+low*.7*math.exp(-t*29)
        else:
            sample=.66*math.sin(math.tau*base*t)*math.exp(-t*18)
            sample+=.25*math.sin(math.tau*base*2.72*t)*math.exp(-t*29)
            sample+=low*.9*math.exp(-t*(62 if name=='pony' else 28))
        previous=n
        sample*=min(1.,t/.0015)*min(1.,(duration-t)/.012)
        values.append(sample)
    peak=max(abs(v) for v in values)
    with wave.open(str(root/(name+'.wav')),'wb') as out:
        out.setparams((1,2,rate,0,'NONE','not compressed'))
        out.writeframes(b''.join(struct.pack('<h',int(v/max(peak,1)*29000)) for v in values))
print('WROTE 4 impact WAVs')
