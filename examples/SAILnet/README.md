# SAILnet

This is a reimplementation of the model described in Zylberberg, Murphy & DeWeese (2011)[^1]

^1: Zylberberg, J., Murphy, J. T., & DeWeese, M. R. (2011). A Sparse Coding Model with Synaptically Local Plasticity and Spiking Neurons Can Account for the Diverse Shapes of V1 Simple Cell Receptive Fields. PLoS Computational Biology, http://doi.org/10.1371/journal.pcbi.1002250

This implementation is known to differ from the published work in the following aspects:

- weight updates are applied after every stimulus, instead of being averaged over 100 stimuli,
- we keep the learning rates constant throughout the simulation,
- the initial weights are drawn from a different distribution.

