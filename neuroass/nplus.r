library("e1071")
library("caret")
library("caTools")
library("ADNIMERGE")
input_file="input_data.csv"
output_file="classifier_output.csv"
output_fig="classifier_output_hippocampus.ps"
pop <- adnimerge[adnimerge$VISCODE=="bl" & (adnimerge$DX=="Dementia" | adnimerge$DX=="CN"),];
pop$ND = as.factor(ifelse(pop$DX == "Dementia", 1, 0))
xt <- pop[, c("Hippocampus", "Entorhinal", "Ventricles", "MidTemp", "AGE", "ICV", "ND")]
classifier_cl <- naiveBayes(ND ~ ., data = xt)
base <- read.csv(input_file)
base$Hippocampus = base$Left.Hippocampus + base$Right.Hippocampus
base$Entorhinal = base$lh.entorhinal.GrayVol + base$rh.entorhinal.GrayVol
base$Ventricles <- base$Left.Inf.Lat.Vent + base$Right.Inf.Lat.Vent + base$Left.Lateral.Ventricle + base$Right.Lateral.Ventricle
base$MidTemp = base$lh.middletemporal.GrayVol + base$rh.middletemporal.GrayVol
base$ICV = base$eTIV
base$ND <- predict(classifier_cl, newdata = base, type = "class")
base$post <- predict(classifier_cl, newdata = base, type = "raw")
base$Nprob <- base$post[,2]
base2e = base[, c("Subject_ID", "Date", "ND", "Nprob")]
write.csv(base2e, file=output_file, row.names=FALSE, quote=FALSE)
a <- lm(base$Hippocampus ~ base$ICV)
base$aHV = base$Hippocampus - a$coefficients[[2]]*(base$ICV - mean(base$ICV, na.rm=TRUE))
postscript(output_fig, width=1024, height=600, bg="white")
plot(base$AGE, base$aHV, main = "Hippocampus volume versus Age", xlab="Age", ylab="adjusted HV", pch=19, col=ifelse(base$ND==1,"red","green"))
dev.off()
a <- lm(base$MidTemp ~ base$ICV)
base$aMidTemp = base$MidTemp - a$coefficients[[2]]*(base$ICV - mean(base$ICV, na.rm=TRUE))
output_fig="classifier_output_middletemporal.ps"
postscript(output_fig, width=1024, height=600, bg="white")
plot(base$AGE, base$aMidTemp, main = "Middle temporal cortex volume versus Age", xlab="Age", ylab="adjusted MidTemp Volume", pch=19, col=ifelse(base$ND==1,"red","green"))
dev.off()
a <- lm(base$Entorhinal ~ base$ICV)
base$aEntorhinal = base$Entorhinal - a$coefficients[[2]]*(base$ICV - mean(base$ICV, na.rm=TRUE))
output_fig="classifier_output_entorhinal.ps"
postscript(output_fig, width=1024, height=600, bg="white")
plot(base$AGE, base$aEntorhinal, main = "Entorhinal cortex volume versus Age", xlab="Age", ylab="adjusted Entorhinal Volume", pch=19, col=ifelse(base$ND==1,"red","green"))
dev.off()

