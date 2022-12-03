#!/usr/bin/env Rscript

radte_version = '0.2.0-dtl'

run_mode = ifelse(length(commandArgs(trailingOnly=TRUE))==1, 'debug', 'batch')
#if (run_mode=='debug') install.packages("/Users/kef74yk/Dropbox (Personal)/repos/ape", repos=NULL, type="source")

#devtools::install_github(repo="cran/ape", ref="master")

library(ape)
library(rkftools)

cat(paste('RADTE version:', radte_version, '\n'))
cat(paste('ape version:', packageVersion('ape'), '\n'))
cat(paste('rkftools version:', packageVersion('rkftools'), '\n'))
cat(paste(version[['version.string']], '\n'))

check_gn_node_name_uniqueness = function(gn_node_table, gn_tree)
for (gn_node_name in gn_node_table[,'gn_node']) {
    n = rkftools::get_node_num_by_name(gn_tree, gn_node_name)
    if (!length(n)==1) {
        stop(paste('Input gene tree contains multiple nodes with the identical name:', gn_node_name))
    }
}
    
pad_branch_length = function(tree, pad_size=1e-6) {
  is_bl_zero = (tree[['edge.length']]<pad_size)
    if (any(is_bl_zero)) {
        txt = paste0(sum(is_bl_zero), ' out of ', length(is_bl_zero))
        txt = paste0(txt, ' branches have small length. Padding with ', pad_size, '.\n')
        cat(txt)
        tree[['edge.length']][is_bl_zero] = pad_size
    }
    return(tree)
}

adjust_branch_length_order = function(tree, min_bl=1e-6) {
    is_bl_zero = (tree[['edge.length']]<=0)
    if (any(is_bl_zero)) {
        stop('The tree contains branch(es) with zero or negative length.')
    }
    min_tree_bl = min(tree[['edge.length']])
    for (i in 1:20) {
        if (min_tree_bl<min_bl) {
            tree[['edge.length']] = tree[['edge.length']] * 10
            min_tree_bl =  min(tree[['edge.length']])
        } else {
            break
        }
    }
    return(tree)
}

save_tree_pdf = function(phy, file, show.age=FALSE, edge_colors=list()) {
    phy = ape::ladderize(phy)
    if (show.age) {
        root_depth = max(node.depth.edgelength(phy))
        node_ages = abs(node.depth.edgelength(phy) - root_depth)
        int_node_ages = node_ages[(length(phy$tip.label)+1):length(node_ages)]
        phy$node.label = paste(phy$node.label, as.character(round(int_node_ages, digits=1)))
    }
    ec2 = rep('black', nrow(phy[['edge']]))
    node_colors = 'black'
    if (length(edge_colors)!=0) {
        for (col in names(edge_colors)) {
            ec2[(phy[['edge']][,2]%in%edge_colors[[col]])] = col
        }
    }
    if (length(edge_colors)!=0) { # Should not be merged to the previous if block
        is_node = (phy[['edge']][,2]>length(phy[['tip.label']]))
        node_order = order(phy[['edge']][,2][is_node])
        node_colors = ec2[is_node][node_order]
        root_num = rkftools::get_root_num(phy)
        for (col in names(edge_colors)) {
            if (root_num %in% edge_colors[[col]]) {
                node_colors = c(col, node_colors) # Adding root
                break
            }
        }
    }
    pdf(file, height=max(3, length(phy$tip.label)/5+1), width=7.2)
    plot(phy, show.node.label=FALSE, show.tip.label=TRUE, cex=0.5, label.offset=0, 
         edge.color='black', root.edge=TRUE)
    nodelabels(text=phy[['node.label']], col=node_colors, bg='white', cex=0.5)
    invisible(dev.off())
}
get_species_names_noscrolls = function (phy, sep = "_"){
  split_names = strsplit(phy[["tip.label"]], sep)
  species_names = c()
  for (sn in split_names) {
    species_names = c(species_names, sn[1])
  }
  return(species_names)
}

cat('RADTE run_mode:', run_mode, '\n')
if (run_mode=='batch') {
    cat('arguments:\n')
    args = commandArgs(trailingOnly=TRUE)
    args = rkftools::get_parsed_args(args, print=TRUE)
} else if (run_mode=='debug') {
    test_type = 'generax'
    #test_type = 'notung'
    args = list()
    args[['max_age']] = 1000
    args[['chronos_lambda']] = 1
    args[['chronos_model']] = 'discrete'
    args[['pad_short_edge']] = 0.001
    args[['pad_short_edge']] = 0.001
    if (test_type=='notung') {
        work_dir = '/Users/kef74yk/Dropbox/repos/RADTE/data/example_notung_01'
        setwd(work_dir)
        args[['species_tree']] = file.path(work_dir, 'species_tree.nwk')
        #args[['gene_tree']] = file.path(work_dir, 'gene_tree.reconciled')
        #args[['notung_parsable']] = file.path(work_dir, 'gene_tree.parsable.txt')
        args[['gene_tree']] = file.path(work_dir, 'gene_tree.nwk.reconciled')
        args[['notung_parsable']] = file.path(work_dir, 'gene_tree.nwk.reconciled.parsable.txt')        
    }
    if (test_type=='generax') {
        work_dir = '/Volumes/kfT7/Dropbox/repos/RADTE/data/example_generax_01'
        setwd(work_dir)
        args[['species_tree']] = file.path(work_dir, 'species_tree.nwk')
        args[['generax_nhx']] = file.path(work_dir, 'gene_tree.nhx')
    }
}


if (('generax_nhx' %in% names(args))&('notung_parsable' %in% names(args))) {
    stop('Only one of --notung_parsable and --generax_nhx should be specified. Exiting.\n')
} else if ('generax_nhx' %in% names(args)) {
    cat('--generax_nhx was detected. GeneRax mode.', '\n')
    mode = 'generax'
    generax_file = args[['generax_nhx']]
} else if ('notung_parsable' %in% names(args)) {
    cat('--notung_parsable was detected. Notung mode.', '\n')
    mode = 'notung'
    gn_file = args[['gene_tree']]
    parsable_file = args[['notung_parsable']]
} else {
    stop('--notung_parsable or --generax_nhx should be specified. Exiting.\n')
}


##Add no scroll function
noscrolls<-"no-scrolls"%in%names(args)
##Add no scroll function

sp_file = args[['species_tree']]
max_age = as.numeric(args[['max_age']])
chronos_lambda = as.numeric(args[['chronos_lambda']])
chronos_model = args[['chronos_model']]

cat('\nStart: species tree processing', '\n')
tree_text0 = scan(sp_file, what=character(), sep="\n", blank.lines.skip=FALSE)
tree_text1 = gsub("'([0-9]+)'", "PLACEHOLDER\\1", tree_text0)
sp_tree = read.tree(text=tree_text1)
if (all(is.na(sp_tree$node.label))) {
    sp_tree
} else {
    sp_tree[['node.label']] = sub('PLACEHOLDER', '', sp_tree[['node.label']])
}
has_nolabel = any(sp_tree[['node.label']]=='')
if (has_nolabel) { stop('Please make sure to label all nodes in the input species tree, including the root node.') }
if (length(args[['pad_short_edge']])) {
    sp_tree = rkftools::pad_short_edges(sp_tree, threshold=args[['pad_short_edge']], external_only=FALSE)
}
sp_tree = rkftools::force_ultrametric(sp_tree, stop_if_larger_change=0.01)
root_depth = max(node.depth.edgelength(sp_tree))
sp_node_ages = abs(node.depth.edgelength(sp_tree) - root_depth)
sp_node_names = c(sp_tree$tip.label, sp_tree$node.label)
sp_node_table = data.frame(node=sp_node_names, age=sp_node_ages, spp=NA, stringsAsFactors=FALSE)
for (sp_sub in ape::subtrees(sp_tree)) {
    subroot_node = sp_sub[['node.label']][1]
    sp_node_table[(sp_node_table$node==subroot_node),'spp'] = paste(sp_sub[['tip.label']], collapse=',')
}
max_tip_age = max(sp_node_table[is.na(sp_node_table[['spp']]),'age'])
if (max_tip_age!=0) {
    cat(paste0('Nonzero tip age(s) were detected (max=', max_tip_age, '). Coercing to 0.\n'))
    sp_node_table[is.na(sp_node_table[['spp']]),'age'] = 0
}
cat('End: species tree processing', '\n\n')

cat('Start: gene tree processing', '\n')

read_generax_nhx = function(generax_file) {
    treetext = readLines(generax_file, warn=FALSE)
    if (length(gregexpr('\\(', treetext)[[1]])-length(gregexpr('\\)', treetext)[[1]])==-1) {
        cat('Number of parentheses in the .nhx is not consistent. Trying to fix.')
        treetext <- gsub("\\);", ";", treetext)
    }
    write(treetext, 'tmp.treetext.txt')
    nhxtree = treeio::read.nhx('tmp.treetext.txt')
    file.remove('tmp.treetext.txt')
    return(nhxtree)
}

if (mode=='generax') {
    cat('Reading GeneRax tree.\n')
    nhxtree = read_generax_nhx(generax_file)

    gn_tree = nhxtree@phylo
    if (rkftools::contains_polytomy(gn_tree)) {
        stop('Input tree contains polytomy. A completely bifurcated tree is expected as input.')
    }
    gn_tree = pad_branch_length(gn_tree, pad_size=args[['pad_short_edge']])
    #gn_tree = adjust_branch_length_order(gn_tree, min_bl=args[['pad_short_edge']])
    cat('Minimum branch length in gene tree:', min(gn_tree[['edge.length']]), '\n')    
    cols = c('event', 'gn_node', 'gn_node_num', 'lower_sp_node', 'upper_sp_node', 'lower_age', 'upper_age')
    gn_node_table = data.frame(nhxtree@data, stringsAsFactors=FALSE)
    gn_node_table[,'event'] = 'S'
    gn_node_table[is.na(gn_node_table[['D']]),'D'] = 'N'
    gn_node_table[(gn_node_table[['D']]=='Y'),'event'] = 'D'
    
    ## Add Hs
    gn_node_table[is.na(gn_node_table[['H']]),'H'] = 'N'
    gn_node_table[(gn_node_table[['H']]!='N'),'event'] = 'H'
    ## Add Hs
    
    colnames(gn_node_table) = sub('^S$', 'lower_sp_node', colnames(gn_node_table))
    gn_node_table[,'upper_sp_node'] = gn_node_table[['lower_sp_node']]
    gn_node_table = gn_node_table[order(gn_node_table[['node']]),]
    gn_node_table[,'gn_node'] = c(gn_tree[['tip.label']], gn_tree[['node.label']])
    gn_node_table[(gn_node_table[['event']]=='D'),'upper_sp_node'] = NA
    
    for (sp_node in unique(gn_node_table[['lower_sp_node']])) {
        node_num = rkftools::get_node_num_by_name(sp_tree, sp_node)
        parent_num = rkftools::get_parent_num(sp_tree, node_num)
        parent_name = rkftools::get_node_name_by_num(sp_tree, parent_num)
        if (identical(parent_name, character(0))) {
            parent_name = NA
        }
        conditions = (gn_node_table[['lower_sp_node']]==sp_node)
        conditions = conditions & (gn_node_table[['event']]=='D')
        gn_node_table[conditions,'upper_sp_node'] = parent_name
        
        ## Add Hs
        for(H in which(gn_node_table[['lower_sp_node']]==sp_node&gn_node_table[['event']]=='H')){
            receiver_node = sub('.*@(.*)@.*','\\1',gn_node_table[H,'H'])
            receiver_num = rkftools::get_node_num_by_name(sp_tree, receiver_node)
            
            receiver_parent_num = rkftools::get_parent_num(sp_tree, receiver_num)
            receiver_parent_name = rkftools::get_node_name_by_num(sp_tree, receiver_parent_num)
            
            node_age = rkftools::get_node_age(sp_tree, node_num)
            parent_age = rkftools::get_node_age(sp_tree, parent_num)
            receiver_age = rkftools::get_node_age(sp_tree,receiver_num)
            receiver_parent_age = rkftools::get_node_age(sp_tree,receiver_parent_num)
            
            gn_node_table[H,'lower_sp_node'] = ifelse(node_age>receiver_age, sp_node, receiver_node)
            gn_node_table[H,'upper_sp_node'] = ifelse(parent_age<receiver_parent_age, parent_name, receiver_parent_name)
        }
        ## Add Hs
        
        
    }
    gn_node_table[,'lower_age'] = NA
    gn_node_table[,'upper_age'] = NA
    
    for (sp_node in sp_node_table[['node']]) {
        node_age = as.numeric(sp_node_table[(sp_node_table[['node']]==sp_node),'age'])
        conditions = (gn_node_table[['lower_sp_node']]==sp_node)
        conditions = conditions & (gn_node_table[['upper_sp_node']]==sp_node)
        conditions[is.na(conditions)] = FALSE
        gn_node_table[conditions,'lower_age'] = node_age
        gn_node_table[conditions,'upper_age'] = node_age
    }
    
    gn_node_table[,'gn_node_num'] = rkftools::get_node_num_by_name(gn_tree, gn_node_table[['gn_node']])
    gn_node_table = data.frame(gn_node_table[,cols], stringsAsFactors=FALSE)
} else if (mode=='notung') {
    cat('Reading NOTUNG tree.\n')
    gn_tree = read.tree(gn_file)
    gn_tree[['node.label']] = gsub("\\'", "",gn_tree[['node.label']])
    if (rkftools::contains_polytomy(gn_tree)) {
        stop('Input tree contains polytomy. A completely bifurcated tree is expected as input.')
    }
    gn_tree = pad_branch_length(gn_tree, pad_size=args[['pad_short_edge']])

    gn_node_table = read_notung_parsable(file=parsable_file, mode='D')
    gn_node_table = merge(gn_node_table, data.frame(lower_age=NA, upper_age=NA, spp=NA), all=TRUE)
    check_gn_node_name_uniqueness(gn_node_table, gn_tree)
    if (nrow(gn_node_table) > 0) {
        gn_node_nums = sapply(gn_node_table[,'gn_node'], function(x){rkftools::get_node_num_by_name(gn_tree, x)})
        gn_node_table$gn_node_num = gn_node_nums
        for (i in 1:nrow(gn_node_table)) {
            if (any(sp_node_table$node==gn_node_table$lower_sp_node[i])) {
                gn_node_table$lower_age[i] = sp_node_table$age[sp_node_table$node==gn_node_table$lower_sp_node[i]]
            }
            if (any(sp_node_table$node==gn_node_table$upper_sp_node[i])) {
                gn_node_table$upper_age[i] = sp_node_table$age[sp_node_table$node==gn_node_table$upper_sp_node[i]]
            }
        }
    } else {
        gn_node_table = gn_node_table[0,]
    }
    
    for (gn_sub in ape::subtrees(gn_tree)) {
        root_node = gn_sub$node.label[1]
        if (! root_node %in% gn_node_table$gn_node) {
            root_num = rkftools::get_node_num_by_name(gn_tree, root_node)
            node_spp = unique(rkftools::leaf2species(gn_sub[['tip.label']]))
            node_spp = sub(' ', '_', node_spp)
            is_spnode_species = TRUE
            for (node_sp in node_spp) {
                is_spnode_species = is_spnode_species & grepl(node_sp, sp_node_table$spp)    
            }
            node_age = min(sp_node_table[is_spnode_species,'age'])
            is_min = (sp_node_table[,'age']==node_age)
            sp_node = sp_node_table[is_min&is_spnode_species,'node']
            ind = nrow(gn_node_table)+1
            gn_node_table[ind,'event'] = "S"
            gn_node_table[ind,'gn_node'] = root_node
            gn_node_table[ind,'gn_node_num'] = root_num
            gn_node_table[ind,'lower_sp_node'] = sp_node
            gn_node_table[ind,'upper_sp_node'] = sp_node
            gn_node_table[ind,'lower_age'] = node_age
            gn_node_table[ind,'upper_age'] = node_age
            gn_node_table[ind,'spp'] = paste(node_spp, collapse='|')
        }
    }
}

if (run_mode=='debug') {
    save_tree_pdf(phy=gn_tree, file="radte_gene_tree_input_debug.pdf", show.age=FALSE)
}
cat('End: gene tree processing', '\n\n')

# Calibration node check

if ((sum(gn_node_table[['event']]%in%c("D","H")) > 0)&(any(is.na(gn_node_table[['upper_age']])))) {
    if(noscrolls){
      gn_spp = unique(get_species_names_noscrolls(gn_tree))
      ##Include this so I don't need to recode my speciesname
    }else{
      gn_spp = unique(rkftools::get_species_names(gn_tree))
    }
    
    num_sp = length(gn_spp)
    cat('# species in the gene tree:', num_sp, '\n')
    cat('Species in the gene tree:', paste(gn_spp, collapse=', '), '\n')
    num_sp_gntree = max(1, ape::getMRCA(sp_tree, gn_spp))
    if (num_sp_gntree==rkftools::get_root_num(sp_tree)) {
        divtime_max = max_age
        divtime_min = max(ape::node.depth.edgelength(sp_tree))
    } else {
        if (length(gn_spp)==1) {
            num_mrca = rkftools::get_node_num_by_name(sp_tree, gn_spp)
        } else {
            num_mrca = ape::getMRCA(sp_tree, gn_spp)
        }
        num_parent = sp_tree$edge[,1][sp_tree$edge[,2]==num_mrca]
        label_mrca = get_node_name_by_num(phy=sp_tree, node_num=num_mrca)
        label_parent = get_node_name_by_num(phy=sp_tree, node_num=num_parent)
        divtime_max = sp_node_table[sp_node_table$node==label_parent,'age']
        divtime_min = sp_node_table[sp_node_table$node==label_mrca,'age']
        cat('Species in the MRCA species tree clade:', paste(sp_node_table[sp_node_table$node==label_mrca,'spp'], collapse=', '), '\n')
        cat('Species in the parent species tree clade:', paste(sp_node_table[sp_node_table$node==label_parent,'spp'], collapse=', '), '\n')
    }
    cat('Divergence time of the parent species tree clade:', divtime_max, '\n')
    cat('Divergence time of the MRCA species tree clade:', divtime_min, '\n')
    is_upper_na = is.na(gn_node_table$upper_age)
    gn_node_table$lower_age[is_upper_na] = divtime_min
    gn_node_table$upper_age[is_upper_na] = divtime_max
}
root_num = rkftools::get_root_num(gn_tree)
if (!endsWith(gn_node_table[(gn_node_table$gn_node_num==root_num),'event'], 'R')) {
    gn_node_table[(gn_node_table$gn_node_num==root_num),'event'] = paste0(gn_node_table[(gn_node_table$gn_node_num==root_num),'event'], '(R)')
}
if (run_mode=='debug') {
    write.table(gn_node_table, file='gn_node_table.debug.tsv', sep='\t', row.names=FALSE)
}

droppable_nodes = c()
flag_first = TRUE


for (gn_node_num in gn_node_table[['gn_node_num']]) {
    if (gn_node_num==root_num) {
        next
    }
    child_lower = gn_node_table[(gn_node_table[['gn_node_num']]==gn_node_num),'lower_age']
    child_upper = gn_node_table[(gn_node_table[['gn_node_num']]==gn_node_num),'upper_age']
    ancestor_nums = get_ancestor_num(gn_tree, gn_node_num)
    ancestor_lower = min(gn_node_table[(gn_node_table[['gn_node_num']]%in%ancestor_nums),'lower_age'])
    ancestor_upper = min(gn_node_table[(gn_node_table[['gn_node_num']]%in%ancestor_nums),'upper_age'])
    is_same_constraint = (child_lower>=ancestor_lower) & (child_upper>=ancestor_upper)
    is_same_constraint = ifelse(length(is_same_constraint)==0, FALSE, is_same_constraint)
    if (is_same_constraint) {
        if (flag_first) {
            cat('calibration node removed because of the constraint identical to or greater than one of the upper nodes (name/id/lower/upper):\n')
            flag_first = FALSE
        }
        droppable_name = rkftools::get_node_name_by_num(gn_tree, gn_node_num)
        cat(paste(c(droppable_name, gn_node_num, child_upper, child_lower), collapse='/'), '\n')
        droppable_nodes = c(droppable_nodes, gn_node_num)
    }
}
cat('\n')
gn_node_table_dropped = gn_node_table[(!gn_node_table[['gn_node_num']] %in% droppable_nodes), ]
gn_node_table_dropped = gn_node_table_dropped[(gn_node_table_dropped[,'gn_node_num']>ape::Ntip(gn_tree)),] # Drop leaves
num_constrained_speciation = sum(grepl('^S', gn_node_table_dropped[,'event']))
num_constrained_duplication = sum(grepl('^D', gn_node_table_dropped[,'event']))

## Add Hs
num_constrained_transfer = sum(grepl('^H', gn_node_table_dropped[,'event']))
## Add Hs

cat('Number of constrained speciation nodes:', num_constrained_speciation, '\n')
cat('Number of constrained duplication nodes:', num_constrained_duplication, '\n')

## Add Hs
cat('Number of constrained transfer nodes:', num_constrained_transfer, '\n')
## Add Hs

# Calibration table
calibration_table = data.frame(
    node=as.integer(gn_node_table_dropped$gn_node_num),
    age.min=as.numeric(gn_node_table_dropped$lower_age),
    age.max=as.numeric(gn_node_table_dropped$upper_age),
    soft.bounds=NA,
    stringsAsFactors=FALSE
)

calibration_table_R = calibration_table[(calibration_table$node==root_num),]
if ("S" %in% gn_node_table_dropped$event) {
    S_nodes = gn_node_table_dropped[(gn_node_table_dropped$event=='S'),'gn_node_num']
    calibration_table_S = calibration_table[calibration_table$node %in% S_nodes,]
} else {
    calibration_table_S = NA
}

calibration_tables = list(
    'RS' = rbind(calibration_table_R, calibration_table_S),
    'S' = calibration_table_S,
    'R' = calibration_table_R
)

# chronos
chronos_out = NULL
chronos_control = chronos.control()
chronos_control$iter.max = 100000
chronos_control$eval.max = 100000
chronos_control$dual.iter.max = 200

if (all(gn_node_table$lower_age==gn_node_table$upper_age)) {
    # Gene tree without duplication nodes
    calibrated_node = "allS"
    cat("Constrained nodes:", calibrated_node, '\n')
    cat("All nodes are speciation nodes. Transferring node ages from species tree without age inference by chronos.", '\n')
    dup_constraint = NA
    gn_spp = c()
    for (gn_gene in gn_tree$tip.label) {
        pos_underbar = gregexpr("_", gn_gene)[[1]]
        gn_sp = substring(gn_gene, 1, pos_underbar[length(pos_underbar)]-1)
        gn_spp = c(gn_spp, gn_sp)
    }
    drop_spp = sp_tree$tip.label[! sp_tree$tip.label %in% gn_spp]
    if (length(drop_spp) > 0) {
        chronos_out = drop.tip(phy=sp_tree, tip=drop_spp, trim.internal = TRUE)
    } else {
        chronos_out = sp_tree
    }
    gn_tip_index = c()
    for (sp in chronos_out$tip.label) {
        gn_tip_index = c(gn_tip_index, grep(sp, gn_tree$tip.label))
    }
    chronos_out$tip.label = gn_tree$tip.label[gn_tip_index]
    chronos_out = transfer_node_labels(phy_from=gn_tree, phy_to=chronos_out)
    current_calibration_table = calibration_table_S
} else {
    # Gene tree with duplication nodes
    chronos_out = 'PLACEHOLDER'
    class(chronos_out) = 'try-error'
    for (cn in c('RS','S','R')) {
        if ("try-error" %in% class(chronos_out)) {
            calibrated_node = cn # This is used in the next block
            current_calibration_table = calibration_tables[[cn]] # This is used in the next block
            cat("\nchronos, calibrated nodes:", cn, '\n')
            chronos_out = try(
                chronos(
                    phy=gn_tree, 
                    lambda=chronos_lambda, 
                    model=chronos_model, 
                    calibration=current_calibration_table, 
                    control=chronos_control
                )
            )
        }
    }
}

if ("try-error" %in% class(chronos_out)) {
    cat('All attempts for divergence time estimation were failed. Exiting.\n')
    q('no')
} else {
    cat('Writing output files.\n')
    chronos_out2 = chronos_out
    num_neg = 1
    counter = 1
    if (length(args[['pad_short_edge']])) {
        while ((num_neg>0)&(counter<100)) {
            cat(paste0(counter, 'th round of padding started.\n'))
            chronos_out2 = rkftools::pad_short_edges(chronos_out2, threshold=args[['pad_short_edge']], external_only=FALSE)
            chronos_out2 = rkftools::force_ultrametric(chronos_out2, stop_if_larger_change=0.01)
            num_neg = sum(chronos_out2[['edge.length']]<0)
            cat(num_neg, 'negative value(s) were detected in estimated branch length.\n\n')
            counter = counter + 1
        }
    }

    write(calibrated_node, file='radte_calibrated_nodes.txt')

    write.tree(chronos_out2, file="radte_gene_tree_output.nwk")
    current_calibration_table = merge(current_calibration_table, gn_node_table[,c('gn_node_num','event')], by.x='node', by.y='gn_node_num', all.x=TRUE)
    current_calibration_table[current_calibration_table$node==calibration_table_R$node,'event'] = 'R'
    write.table(current_calibration_table, file='radte_calibration_used.tsv', sep='\t', quote=FALSE, row.names=FALSE)

    calibration_table = merge(calibration_table, gn_node_table[,c('gn_node_num','event')], by.x='node', by.y='gn_node_num', all.x=TRUE)
    write.table(calibration_table, file='radte_calibration_all.tsv', sep='\t', quote=FALSE, row.names=FALSE)

    gn_node_table$spp = NULL
    write.table(gn_node_table, file='radte_gene_tree.tsv', sep='\t', quote=FALSE, row.names=FALSE)

    sp_node_table$spp = NULL
    write.table(sp_node_table, file='radte_species_tree.tsv', sep='\t', quote=FALSE, row.names=FALSE)
    
    node_nums = (length(chronos_out2[['tip.label']])+1):max(chronos_out2[['edge']])
    noncalibrated_nodes = node_nums[!node_nums %in% current_calibration_table[['node']]]
    ec = list('red'=noncalibrated_nodes, 'blue'=current_calibration_table[['node']])
    save_tree_pdf(phy=gn_tree, file="radte_gene_tree_input.pdf", show.age=FALSE, edge_colors=ec)
    save_tree_pdf(phy=chronos_out2, file="radte_gene_tree_output.pdf", show.age=TRUE, edge_colors=ec)
    save_tree_pdf(phy=sp_tree, file="radte_species_tree.pdf", show.age=TRUE)

    cat('Calibrated nodes:', calibrated_node, '\n')
    cat('Tree height:', max(ape::node.depth.edgelength(sp_tree)), 'million years', '\n')
    is_max_age = (calibration_table[,'age.max']==max_age)
    num_spnode_used_for_constraint = nrow(unique(calibration_table[!is_max_age,c('age.min','age.max')]))
    cat('Number of species tree node used for the gene tree constraint:', num_spnode_used_for_constraint, '\n')    
    cat('Completed: RADTE divergence time estimation', '\n')
}


