
from numpy import *
from matplotlib import pyplot
from matplotlib.colors import LogNorm
from sklearn.cluster import KMeans
data = loadtxt('')
kmeans=KMeans(n_clusters=100)
clusters=kmeans.fit_predict(data)
centroids=kmeans.cluster_centers_
fig=figure()
axis=fig.add_subplot(111)
axis.hist2d(data[:,0],data[:,1],bins=300,norm=LogNorm())
axis.scatter(centroids[:,0],centroids[:,1],c="g",marker="s")
show()
