
########################################################################
#                                                                      #
#        v1.1 An R script to  perform a PCA followed by                #
#   a Hierarchical Clustering on Principle Components (HCPC)           #
#                     on quantitative data                             #
#                                                                      #
#  Authors: Joan Perez*                                                #
#          mail:  joan.perez@univ-cotedazur.fr                         # 
#                                                                      #
#          Giovanni Fusco*                                             #
#          mail:  Giovanni.FUSCO@univ-cotedazur.fr                     #
#                                                                      #
#          *Univ. C�te d'Azur, CNRS, ESPACE, UMR7300                   #
#          98 Bd Herriot, BP 3209, 06204 Nice, France                  #
#                                                                      #
########################################################################

# R version 3.5.1
# other attached packages:
# fpc_2.1-11.1     FactoMineR_1.41  factoextra_1.0.5 ggplot2_3.1.0 


# The dataset should be composed of one ID column located in first 
# position. The other columns must be quantitative variables.
# The dataset shall be in a .txt file
# For this example, the Data_India.txt file is used. 

## 1. PREREQUISES -------------------------------------------------------

# Set working directory
setwd("C:/Users/...")
main.directory <- getwd()
# Data importation
df <- read.delim2("Data_India.txt")
# Packages loading - needs to be previously installed
library(factoextra)
library(FactoMineR)
library(missMDA)
library(fpc)

# Base 10 log transformation of Air_Flows
# Replace -Inf by 0 within the dataframe
# Replace NA by 0 within MACRO_AREA_COMPACITY
df$AIR_FLOWS <- log10(df$AIR_FLOWS)
df[ df == "-Inf" ] = 0
df$MACRO_AREA_COMPACITY <- replace(df$MACRO_AREA_COMPACITY, 
                                   is.na(df$MACRO_AREA_COMPACITY), as.numeric(0.0))
# default method to centers and scales 
df.scale <- as.data.frame(scale(df[,-1:-2]))

## 2. CALCULATION ------------------------------------------------------

# ## Regularized iterative PCA algorithm first imputs missing values. A random initialization
# is then performed: the initial values are drawn from a gaussian distribution with
# mean and standard deviation calculated from the observed values.
df.scale.imp <- imputePCA(df.scale, ncp = 6, scale = FALSE, 
                      method = "Regularized", seed = 2, nb.init = 100, maxiter = 1000)
df.scale <- df.scale.imp[[1]]

# 
# ## Principal Component Analysis (PCA), output recorded on 6 PCs
res.pca <- PCA(df.scale, ncp = 6, scale.unit = FALSE, graph = FALSE)


dir.create("PCA_Results")
setwd(paste0(main.directory,'/PCA_Results'))

eigenvalues <- res.pca$eig
capture.output(eigenvalues[, 1:3], file = "PCs_explained_variance.txt")
capture.output(res.pca$var$cos2, file = "Cos2_Quality_of_variables.txt")
capture.output(res.pca$var$contrib, file = "Varibles_contribution_to_PCs.txt")

png(file="Scree_plot.png",width=800,height=650)
fviz_eig(res.pca, linecolor = "#FC4E07", addlabels = TRUE, ylim = c(0, 20), main = "", font.x = 18, font.y = 18, format.scale = TRUE)
dev.off()

png(file="Factor_Map.png",width=900,height=750)
fviz_pca_var(res.pca, col.var="contrib",    
             gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07"), repel = TRUE)
dev.off()

png(file="Scatter_Plot.png",width=600,height=550)
fviz_pca_ind(res.pca, col.ind="cos2", geom = "point") +
  scale_color_gradient2(low="white", mid="blue",
                        high="red", midpoint = 0.3)
dev.off()


# Hierarchical Clustering
cl <- hclust(dist(res.pca$ind[[3]]), method = "complete")

# ## WSS Calculation
wss <- function(d) {
  sum(scale(d, scale = FALSE)^2)
}

wrap <- function(i, hc, x) {
  cl <- cutree(hc, i)
  spl <- split(x, cl)
  wss <- sum(sapply(spl, wss))
  wss
}
res <- sapply(seq.int(1, 20), wrap, h = cl, x = res.pca$ind[[3]])

# ## Calinhara Calculation
res.list <- list()
for(i in 1:20)
{
  temp <- cutree(cl, i)
  res.list[[i]] <- temp
}

res.vc <- vector()
for(i in 1:20)
{
  temp <- calinhara(res.pca$ind[[3]],res.list[[i]])
  res.vc[[i]] <- temp
}


#Plot WSS and Calinhara
setwd(main.directory)
dir.create("HCPC_TEST")
setwd(paste0(main.directory,'/HCPC_TEST'))

png(file="WSS_CH.png",width=1250,height=650)
par(mfrow=c(1,2))
plot(seq_along(res[1:20]), res[1:20], type = "o", pch = 19, xlab = "Cluster Numbers", ylab = "WSS Values")
axis(1, at=1:20, labels= c(1:20))
plot(res.vc, type = "o", pch = 19, xlab = "Cluster Numbers", ylab = "Calinhara Values")
axis(1, at=c(1:20), labels= c(1:20))
dev.off()

#Hierarchical clustering with 10 clusters
setwd(main.directory)
dir.create("HCPC_9CL")
setwd(paste0(main.directory,'/HCPC_9CL'))

HCPC9CL <- HCPC(res.pca,nb.clust=9, metric = "euclidean", method = "complete")

#Hierarchical clustering record
capture.output(summary(HCPC9CL$data.clust$clust), file = "Nb_of_individuals_and_clusters.txt")
capture.output(HCPC9CL$desc.var, file = "p_values_per_variables.txt")

png(file="Dendrogram.png",width=800,height=650)
fviz_dend(HCPC9CL, cex = 0.5, rect = TRUE, rect_fill = TRUE)
dev.off()

png(file="Cluster_Map.png",width=800,height=650)
fviz_cluster(HCPC9CL, repel = FALSE, geom = "point",           
             show.clust.cent = TRUE, palette = "jco", ggtheme = theme_minimal(),
             main = "Factor map")
dev.off()

png(file="Cluster_Map_on_PCA_Axis_Centers.png",width=800,height=650)
fviz_pca_ind(res.pca, label="none", habillage=HCPC9CL$data.clust$clust, 
             palette = "jco", ggtheme = theme_minimal(), addEllipses=TRUE, ellipse.level=0.95)
dev.off()

png(file="Cluster_Map_with_Factors.png",width=800,height=650)
fviz_pca_biplot(res.pca, habillage = HCPC9CL$data.clust$clust, addEllipses = TRUE,
                col.var = "black", label = "var", palette="jco") + theme_minimal()
dev.off()

png(file="3D_MAP.png",width=800,height=650)  
plot(HCPC9CL, choice = "3D.map",ind.names=FALSE )
dev.off()

write.csv(cbind(df[,1:2],HCPC9CL$data.clust),"cluster_assignment.csv")



