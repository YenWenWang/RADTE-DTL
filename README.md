# Overview
**R**econciliation-**A**ssisted **D**ivergence **T**ime **E**stimation (**RADTE**) is a method to date gene trees with the aid of dated species trees.
This program can handle a rooted gene tree containing duplication/loss events.
The divergence time of duplication nodes are estimated while constraining speciation nodes.
Currently, only point estimates are supported to constrain speciation events.
Confidence intervals of species divergence time will be incorporated in future. 
**RADTE** first attempts to constrain all available calibration points transferred from the species tree (**R**, root node; **D**, duplication node; **S**, speciation node) for the divergence time estimation by `chronos` from the **ape** package.
If the estimation fails, the constraints are gradually relaxed until successful estimation is obtained.
**RADTE is under development. Use at your own risk. Any feedback is welcomed.**

![](img/radte_method.svg)

# Dependency
* [R 3.x](https://www.r-project.org/)
* [ape](http://ape-package.ird.fr/)
* [rkftools](https://github.com/kfuku52/rkftools)
* [NOTUNG](http://www.cs.cmu.edu/~durand/Notung/) (RADTE doesn't directly handle it but needs its outputs.)

# Options
#### `--species_tree`
Species tree with estimated divergence time.
Leaves (species) should be labeled as `GENUS_SPECIES` (e.g., Homo_sapiens).
The tree is expected to be ultrametric and branch lengths should represent evolutionary time (e.g., million years).
#### `--gene_tree`
Leaves (genes) should be labeled as `GENUS_SPECIES_GENEID` (e.g., Homo_sapiens_ENSG00000102144). The tree is expected to be non-ultrametric and branch lengths should represent substitutions per site. 
Use the tree that **NOTUNG** produces because its internal nodes are correctly labeled in accordance with the **NOTUNG parsable file**, another input for this program.
#### `--notung_parsable`
This program uses an output file from **NOTUNG** (tested with version 2.9) to acquire the species–gene relationships in phylogeny reconciliation.
See **Examples** for details.
#### `--max_age`
If duplication nodes are deeper than the root node of the species tree, this value will be used as an upper limit.
#### `--chronos_lambda`
See `chronos` in the [**ape** documentation](https://www.rdocumentation.org/packages/ape/versions/5.2/topics/chronos).
#### `--chronos_model`
See `chronos` in the [**ape** documentation](https://www.rdocumentation.org/packages/ape/versions/5.2/topics/chronos).

# Examples
```
# Run NOTUNG in the reconciliation mode
# Don't forget to specify --parsable
java -jar -Xmx2g Notung-2.9.jar \
-s species_tree.nwk \
-g gene_tree_input.nwk \
--reconcile \
--infertransfers "false" \
--treeoutput newick \
--parsable \
--speciestag prefix \
--maxtrees 1 \
--nolosses \
--outputdir .

# Run RADTE
Rscript radte.R \
--species_tree=species_tree.nwk \
--gene_tree=gene_tree_input.nwk.reconciled \
--notung_parsable=gene_tree_input.nwk.reconciled.parsable.txt \
--max_age=1000 \
--chronos_lambda=1 \
--chronos_model=discrete

```
#### species_tree.nwk
![](img/radte_species_tree.svg)

#### gene_tree_input.nwk
![](img/radte_gene_tree_input.svg)

#### gene_tree_output.nwk
![](img/radte_gene_tree_output.svg)

# Licensing
This program is BSD-licensed (3 clause). See [LICENSE](LICENSE) for details.