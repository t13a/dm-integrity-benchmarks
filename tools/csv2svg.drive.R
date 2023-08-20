#!/usr/bin/env Rscript

library(dplyr, warn.conflicts=F)
library(ggplot2)
library(gridExtra, warn.conflicts=F)

plotThroughput <- function(d, title) {
    ggplot(d, aes(x=bw_mbps, xmax=max(bw_mbps) * 1.2, y=config, fill=bw_mbps, label=bw_mbps)) +
        geom_bar(position='dodge', stat='identity', width=0.75) +
        geom_text(hjust=+1.1, size=2) +
        facet_wrap(~rw) +
        scale_x_reverse() +
        scale_y_discrete(limits=rev, position='right') +
        labs(x='Throughput (MB/s)', y='Configuration') +
        theme(axis.text.y=element_text(hjust=0), legend.position='left')
}

args = commandArgs(trailingOnly=T)
src = args[1]
dst = args[2]
dst_height = args[3]
regex_fs = args[4]
regex_rw = args[5]

data <- read.csv(src) %>% 
    filter(grepl(regex_fs, config)) %>% 
    filter(grepl(regex_rw, rw))
p1 = plotThroughput(filter(data, grepl('^seq-', rw)))
p2 = plotThroughput(filter(data, grepl('^rnd-', rw)))
title = gsub('.+/([^/]+)\\.[^.]+$', '\\1', dst)
ggsave(dst, grid.arrange(p1, p2, top=title), width=8, height=strtoi(dst_height), dpi=300)
