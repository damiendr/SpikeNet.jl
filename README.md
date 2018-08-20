
# SpikeNet

SpikeNet is a minimalist neural network simulator written in Julia. It is meant to run smallish networks of spiking or hybrid neurons with pretty good performance and a focus on experimentation with non-standard models.

SpikeNet does a lot less than other simulators. In fact it's hardly a simulator at all! There is no main loop, only a collection of tools that you can use to turn a set of model equations into a working simulation:

- elementwise kernels with a syntax inspired by Brian
- running kernels on populations
- running kernels on pathways
- recording state

SpikeNet supports both spikes and rates, but assumes that the network activity is sparse -- it is not optimised to run large networks of rate neurons, as it will not try to use efficient matrix operations.


