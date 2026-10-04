"""Original composed loops and synthesized foley for issue 97; no samples or third-party recordings.
All stems share tempo/length and are normalized together. Reruns leave the original five legacy loops intact.
"""
from pathlib import Path
import json
import numpy as np
import make_game_audio as a
# Tonal synthesized material fits 24 kHz; leave legacy 44.1 kHz sources intact.
a.SR=24000

ROOT=Path(__file__).resolve().parents[2]
CONFIG=json.loads((ROOT/'game/data/economy/audio.json').read_text())
OUT=ROOT/'game/assets/audio'
# Distinct eight-bar compositions: tempo, tonic, four chord degrees, melody motif and rhythmic offset.
SCORES=[(104,60,[0,5,9,7],[0,4,7,9,7,4,2,7]),(96,62,[0,7,5,9],[2,4,7,4,9,7,4,2]),
(112,59,[0,9,5,7],[0,7,11,7,4,2,7,9]),(88,65,[0,5,2,7],[4,7,9,7,2,4,7,11]),
(102,57,[0,5,7,0],[0,2,4,7,4,2,9,7]),(108,55,[0,7,5,9],[0,0,7,4,2,7,9,4]),
(92,64,[0,5,9,7],[7,4,2,0,4,7,9,11]),(118,60,[0,9,2,7],[9,7,4,2,7,9,11,7]),
(78,62,[0,5,9,2],[0,4,9,7,4,2,0,7]),(100,67,[0,7,9,5],[0,7,9,11,9,7,4,2]),
(110,57,[0,5,7,9],[0,4,2,7,9,7,2,4]),(124,57,[0,5,8,7],[0,3,7,8,7,3,2,7]),
(116,62,[0,5,7,0],[0,4,7,11,9,7,4,7]),(100,65,[0,5,7,0],[0,4,7,12,11,9,7,4]),
(72,60,[0,9,5,7],[7,4,2,0,2,4,9,7]),(106,67,[0,5,2,7],[0,2,4,7,9,7,4,2])]

def compose(tag,score,index):
 bpm,tonic,degrees,motif=score;beat=60/bpm;length=32*beat;n=int(length*a.SR)
 layers=[np.zeros(n+int(3*a.SR)) for _ in range(3)]
 rng=np.random.default_rng(9700+index)
 for bar in range(8):
  root=tonic+degrees[bar%4];third=3 if tag=='crisis' else 4
  chord=[root,root+third,root+7,root+11 if third==4 else root+10]
  for j,note in enumerate(chord):a.add(layers[0],a.epiano(a.midi(note),beat*3.8,.09,beat*1.6),bar*4*beat+j*.015)
  for j in range(4):
   note=tonic+12+motif[(j+bar*2)%len(motif)]
   a.add(layers[0],a.epiano(a.midi(note),beat*.8,.12,beat*.6),bar*4*beat+j*beat+(beat*.5 if bar%2 else 0))
   a.add(layers[1],a.bass(a.midi(root-12+(7 if j%2 else 0)),beat*.8,.19),bar*4*beat+j*beat)
   if j%2==0:a.add(layers[1],a.kick(.17),bar*4*beat+j*beat)
   else:a.add(layers[1],a.brush(rng,.05),bar*4*beat+j*beat)
  for j in range(8):
   a.add(layers[2],a.hat(rng,.025,j==7),bar*4*beat+j*beat/2)
   note=tonic+24+motif[(j+bar)%8]
   a.add(layers[2],a.epiano(a.midi(note),beat*.35,.04,beat*.22),bar*4*beat+j*beat/2)
 folded=[]
 for layer in layers:
  layer=a.reverb(layer,1.1,.10,9700+index)
  wave=layer[:n].copy();tail=layer[n:];wave[:len(tail)]+=tail
  folded.append(wave)
 peak=max(1,np.max(np.abs(sum(folded)))/.70)
 for suffix,wave in zip(['','_pulse','_lift'],folded):a.write_ogg(str(OUT/'music'/(tag+suffix+'.ogg')),wave/peak,stereo=False,q=0)
 print('composed',tag,round(length,2),'seconds',flush=True)

def ambience(tag,index,night=False):
 duration=20;n=int(duration*a.SR);t=np.arange(n)/a.SR;rng=np.random.default_rng(9800+index)
 noise=rng.standard_normal(n)
 water=tag in ['riverside','harbor','old_town'];mechanical=tag in ['industrial','airport','factory']
 hz=800 if water else 280 if mechanical else 1200
 wave=a.lowpass(noise,hz)*(.08 if water else .025)
 wave*=.6+.25*np.sin(2*np.pi*t/(5+index%4))
 if mechanical:wave+=.018*np.sin(2*np.pi*(55+index%5*12)*t)*(1+.3*np.sin(2*np.pi*.4*t))
 # Sound signatures: water, machinery, campus birds, market clinks, airport PA chimes; no recorded speech.
 times=[2.2,7.8,14.3,18.1]
 for j,start in enumerate(times):
  if tag=='airport':
   cue=sum(a.epiano(a.midi(note),.6,.09,.2) for note in [72,79])
  elif tag in ['cafe','old_town','shopping_street','hotel']:cue=a.epiano(1600+j*90,.12,.04,.025)
  elif tag in ['university','residential','luxury_heights','riverside','harbor']:
   dur=.32;ct=np.arange(int(dur*a.SR))/a.SR
   cue=np.sin(2*np.pi*(1600+900*np.sin(2*np.pi*ct*6))*ct)*a.env(len(ct),.01,.09)*.025
  else:cue=a.lowpass(rng.standard_normal(int(.14*a.SR)),1000)*a.env(int(.14*a.SR),.015,.035)*.06
  a.add(wave,cue,start)
 if night:wave*=.48;wave+=.004*np.sin(2*np.pi*2300*t)*(np.sin(2*np.pi*t*5)>0)
 # Circular end fade avoids an abrupt boundary without adding a silent gap.
 edge=int(.1*a.SR);wave[:edge]*=np.linspace(0,1,edge);wave[-edge:]*=np.linspace(1,0,edge)
 a.write_ogg(str(OUT/'ambient'/(tag+('_night' if night else '_day')+'.ogg')),wave,stereo=False,q=0)

if __name__=='__main__':
 for i,(tag,score) in enumerate(zip(CONFIG['tracks'],SCORES)):compose(tag,score,i)
 for i,tag in enumerate(CONFIG['districts']):
  ambience(tag,i);ambience(tag,i,True)
 for i,tag in enumerate(['factory','hotel','office','cafe']):
  ambience(tag,30+i);(OUT/'ambient'/(tag+'_day.ogg')).replace(OUT/'ambient'/(tag+'.ogg'))
 for i,tag in enumerate(CONFIG['feedback'].values()):
  cue=np.zeros(int(.32*a.SR))
  for j,note in enumerate([60+i,67+i]):a.add(cue,a.epiano(a.midi(note),.2,.18,.07),j*.10)
  a.write_ogg(str(OUT/'sfx'/(tag+'.ogg')),cue,stereo=False,q=3)
 total=sum(p.stat().st_size for p in OUT.rglob('*.ogg'));print('Total audio bytes:',total)
 assert total<=CONFIG['audio_budget_bytes']
