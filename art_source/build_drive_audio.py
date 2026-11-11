"""Offline, seamless stylized wheel/gel loops. Runtime only plays the saved WAVs."""
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio/drive'
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 44100
N = RATE * 2
t = np.arange(N) / RATE
rng = np.random.default_rng(417)

def grain(low, high):
    frequencies = np.fft.rfftfreq(N, 1 / RATE)
    spectrum = np.exp(1j * rng.uniform(0, np.pi * 2, len(frequencies)))
    spectrum *= np.exp(-np.square(frequencies / high) * 2) * (1 - np.exp(-np.square(frequencies / low)))
    data = np.fft.irfft(spectrum, n=N)
    return data / max(np.std(data), 0.001)

def knock(rate, frequency, decay):
    age = np.mod(t, 1 / rate)
    return np.sin(np.pi * 2 * frequency * age) * np.exp(-age * decay) * (1 - np.exp(-age * 900))

def save(name, data):
    data = data - np.mean(data)
    data *= min(0.65 / np.max(np.abs(data)), 0.16 / np.sqrt(np.mean(data ** 2)))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes((data * 32767).astype('<i2').tobytes())
    print(name, 'RMS', round(float(np.sqrt(np.mean(data ** 2))), 4), 'seam', round(float(abs(data[-1]-data[0])), 5))

# All frequencies and rhythmic periods repeat across the two-second loop boundary.
wood = grain(55, 1100)
save('pony_wheels', wood * .11 * (.65 + .35 * np.cos(2*np.pi*6*t))
     + .38 * knock(6, 185, 70) + .12 * knock(3, 310, 42)
     + .08 * np.sin(2*np.pi*64*t) * (1 + .25*np.cos(2*np.pi*3*t)))
axle = grain(35, 620)
save('pumpkin_axle', axle * .1 * (.75 + .25*np.cos(2*np.pi*4*t))
     + .27 * np.sin(2*np.pi*47.5*t + .28*np.sin(2*np.pi*2*t))
     + .18 * knock(4, 99, 35) + .06 * knock(8, 210, 65))
gel = grain(100, 850)
save('slime_roll', gel * .12 * (.55 + .45*np.cos(2*np.pi*3*t))
     + .20 * np.sin(2*np.pi*109*t + 2.2*np.sin(2*np.pi*3*t))
     * (.7 + .3*np.cos(2*np.pi*3*t)) + .1 * knock(6, 175, 42))
step_t = np.arange(int(RATE*.14))/RATE
step = np.sin(2*np.pi*(185*step_t-370*step_t**2)) * np.exp(-step_t*38)
step += rng.normal(0, .12, len(step_t)) * np.exp(-step_t*60)
step *= np.minimum(1, step_t/.003) * np.minimum(1, (.14-step_t)/.015)
save('slime_step', step)
