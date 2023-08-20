#!/usr/bin/env Rscript

library(dplyr)
library(ggplot2)
library(gridExtra)

plotThroughput <- function(d) {
    ggplot(d, aes(x=bw_mbps, y=config, label=bw_mbps, fill=drive, group=drive)) +
        geom_bar(position="dodge", stat='identity', width=0.75) +
        facet_wrap(~rw) +
        scale_x_reverse() +
        scale_y_discrete(limits=rev, position="right") +
        labs(x='Throughput (MB/s)', y='Configuration', fill='Drive') +
        guides(fill=guide_legend(reverse=T)) +
        theme(axis.text.y=element_text(hjust=0), legend.position="left")
}

args = commandArgs(trailingOnly=T)
src = args[1]
dst = args[2]
dst_height = args[3]
regex_drive = args[4]
regex_fs = args[5]
regex_rw = args[6]

data <- read.csv(src) %>% 
    filter(grepl(regex_drive, drive)) %>% 
    filter(grepl(regex_fs, config)) %>% 
    filter(grepl(regex_rw, rw))
p1 = plotThroughput(filter(data, grepl("^seq-", rw)))
p2 = plotThroughput(filter(data, grepl("^rnd-", rw)))
title = gsub('.+/([^/]+)\\.[^.]+$', '\\1', dst)
ggsave(dst, grid.arrange(p1, p2, top=title), width=8, height=strtoi(dst_height), dpi=300)
