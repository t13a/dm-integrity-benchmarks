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

saveThroughput <- function(f, h, d) {
    p1 = plotThroughput(filter(d, grepl("^seq-", access)))
    p2 = plotThroughput(filter(d, grepl("^rnd-", access)))

    a = grid.arrange(p1, p2)
    ggsave(f, a, width=8, height=h, dpi=300)
}

saveThroughput("gen/fio.svg", 8, data)
saveThroughput("gen/fio-summary.svg", 4, filter(data, grepl("^(01|03|12|13|16)-", case)))
