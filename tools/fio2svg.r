#!/usr/bin/env Rscript

library(dplyr)
library(ggplot2)
library(gridExtra)

data <- read.csv("gen/fio.csv", header=F, col.names=c('access', 'case', 'bps', 'mibps'))

plotThroughput <- function(d) {
    ggplot(d, aes(x=mibps, xmax=max(mibps)*1.2, y=case, label=mibps, fill=mibps)) +
        geom_bar(stat='identity', width=0.75) +
        geom_text(hjust=-0.1, size=3) +
        facet_wrap(~access) +
        scale_y_discrete(limits=rev) +
        labs(x='Throughput (MiB/s)', y='') +
        theme(axis.text.y=element_text(hjust=0), legend.position="none")
}

p1 = plotThroughput(filter(data, grepl("^seq-", access)))
p2 = plotThroughput(filter(data, grepl("^rand-", access)))

a = grid.arrange(p1, p2)
ggsave("gen/fio.svg", a, width=8, height=8, dpi=300)
