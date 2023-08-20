#!/usr/bin/env Rscript

library(dplyr, warn.conflicts=F)
library(ggplot2)
library(gridExtra, warn.conflicts=F)

plotThroughput <- function(d, title) {
    ggplot(d, aes(x=bw_mbps, xmax=max(bw_mbps)*1.2, y=config, fill=bw_mbps)) +
        geom_bar(stat='identity', width=0.75) +
        geom_text(aes(label=bw_mbps), position=position_dodge(width=1), size=2.5, hjust=+1.1, show.legend=F) +
        facet_wrap(~rw) +
        scale_x_reverse() +
        scale_y_discrete(limits=rev, position='right') +
        labs(x='Throughput (MB/s)', y='Configuration') +
        theme(axis.text.y=element_text(hjust=0), legend.position='none')
}
#        geom_text(hjust=+1.2) +

args = commandArgs(trailingOnly=T)
src = args[1]
dst = args[2]
regex_fs = args[3]
regex_rw = args[4]

data <- read.csv(src) %>% 
    filter(grepl(regex_fs, config)) %>% 
    filter(grepl(regex_rw, rw))
p1 = plotThroughput(filter(data, grepl('^seq-', rw)))
p2 = plotThroughput(filter(data, grepl('^rnd-', rw)))
title = gsub('.+/([^/]+)\\.[^.]+$', '\\1', dst)
ggsave(dst, grid.arrange(p1, p2, top=title), width=8, height=2+nrow(data)/12, dpi=300)
