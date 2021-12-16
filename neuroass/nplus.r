library("e1071")
library("caret")
library("caTools")
library("ADNIMERGE")
input_file="input_data.csv"
output_file="classifier_output.csv"
output_png="classifier_output.png"
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
base$ND <- predict(classifier_cl, newdata = base)
base2e = base[, c("Subject_ID", "ND")]
write.csv(base2e, file=output_file, row.names=FALSE)
png(output_png, width=1024, height=600, bg="white")
plot(base$AGE, base$Hippocampus, main = "Hippocampus Volume versus Age", xlab="Age", ylab="HV", pch=19, col=ifelse(base$ND==1,"red","green"))
dev.off()
