---
layout: post
title: "Comparing Clustering"
category: posts
published: "true"
---

# [{{ page.title }}]({{ page.url }})

I've done a fair amount with unsupervised learning recently. Most of my code has
leveraged the <a href="http://scikit-learn.org/stable/">scikit-learn
libraries</a> so I am becoming more familiar with that code base and their
conventions.

Among other positive qualities, scikit-learn is particularly good at attracting
contributions with excellent documentation. When I was first exposed to scikit-
learn's clustering suite a few years ago, I really appreciated <a
href="http://scikit-
learn.org/stable/auto_examples/cluster/plot_cluster_comparison.html">this
demo</a> showing how the various clustering algorithms perform on a few
canonical datasets.  I've copied the main plot below.

![sklearn-clustering]({{ site.baseurl
}}/images/sklearn_cluster_old.png){:width="100%"}

After working in this area for a while, I felt like this plot does not tell the
whole story.  For one thing, <a href="http://scikit-
learn.org/stable/modules/mixture.html">Gaussian Mixture Model (GMM)</a>
Clustering is not included.  The absences of GMMs is striking to me because I
find GMMs to be the most intuitive clustering idea.  Also, GMMs are very robust
in applications where clusters have varying densities.

I made <a href="https://github.com/scikit-learn/scikit-learn/pull/6305">pull
request</a> to add GMMs, but it has not been merged yet.  In the process of
making the PR, there were several good suggestions on how to add more canonical
datasets to the plot in order to show a wider range of performance.

## Code


{% highlight python %}
%matplotlib inline
import seaborn as sns
from pylab import rcParams
rcParams['figure.figsize'] = (10.0, 7.0)

import time
import warnings

import numpy as np
import matplotlib.pyplot as plt

from sklearn import cluster, datasets, mixture
from sklearn.neighbors import kneighbors_graph
from sklearn.preprocessing import StandardScaler
from itertools import cycle, islice

np.random.seed(0)

# ============
# Generate datasets. We choose the size big enough to see the scalability
# of the algorithms, but not too big to avoid too long running times
# ============
n_samples = 1500
noisy_circles = datasets.make_circles(n_samples=n_samples, factor=.5,
                                      noise=.05)
noisy_moons = datasets.make_moons(n_samples=n_samples, noise=.05)
blobs = datasets.make_blobs(n_samples=n_samples, random_state=8)
no_structure = np.random.rand(n_samples, 2), None

# Anisotropicly distributed data
random_state = 170
X, y = datasets.make_blobs(n_samples=n_samples, random_state=random_state)
transformation = [[0.6, -0.6], [-0.4, 0.8]]
X_aniso = np.dot(X, transformation)
aniso = (X_aniso, y)

# blobs with varied variances
varied = datasets.make_blobs(n_samples=n_samples,
                             cluster_std=[1.0, 2.5, 0.5],
                             random_state=random_state)

# ============
# Set up cluster parameters
# ============

default_base = {'quantile': .3,
                'eps': .3,
                'damping': .9,
                'preference': -200,
                'n_neighbors': 10,
                'n_clusters': 3}

datasets = [
    (noisy_circles, {'damping': .77, 'preference': -240,
                     'quantile': .2, 'n_clusters': 2}),
    (noisy_moons, {'damping': .75, 'preference': -220, 'n_clusters': 2}),
    (varied, {'eps': .18, 'n_neighbors': 2}),
    (aniso, {'eps': .15, 'n_neighbors': 2}),
    (blobs, {}),
    (no_structure, {})]


plt.figure(figsize=(9 * 2 + 3, 12.5))
plt.subplots_adjust(left=.02, right=.98, bottom=.001, top=.96, wspace=.05,
                    hspace=.01)

plot_num = 1
for i_dataset, (dataset, params) in enumerate(datasets):
    # update parameters with dataset-specific values
    defaults = default_base.copy()
    defaults.update(params)

    X, y = dataset

    # normalize dataset for easier parameter selection
    X = StandardScaler().fit_transform(X)

    # estimate bandwidth for mean shift
    bandwidth = cluster.estimate_bandwidth(X, quantile=defaults['quantile'])

    # connectivity matrix for structured Ward
    connectivity = kneighbors_graph(
        X, n_neighbors=defaults['n_neighbors'], include_self=False)
    # make connectivity symmetric
    connectivity = 0.5 * (connectivity + connectivity.T)

    # ============
    # Create cluster objects
    # ============
    ms = cluster.MeanShift(bandwidth=bandwidth, bin_seeding=True)
    two_means = cluster.MiniBatchKMeans(n_clusters=defaults['n_clusters'])
    ward = cluster.AgglomerativeClustering(
        n_clusters=defaults['n_clusters'], linkage='ward',
        connectivity=connectivity)
    spectral = cluster.SpectralClustering(
        n_clusters=defaults['n_clusters'], eigen_solver='arpack',
        affinity="nearest_neighbors")
    dbscan = cluster.DBSCAN(eps=defaults['eps'])
    affinity_propagation = cluster.AffinityPropagation(
        damping=defaults['damping'], preference=defaults['preference'])
    average_linkage = cluster.AgglomerativeClustering(
        linkage="average", affinity="cityblock",
        n_clusters=defaults['n_clusters'], connectivity=connectivity)
    birch = cluster.Birch(n_clusters=defaults['n_clusters'])
    gmm = mixture.GaussianMixture(
        n_components=defaults['n_clusters'], covariance_type='full')

    clustering_algorithms = (
        ('M.B.KMeans', two_means),
        ('Aff.Prop.', affinity_propagation),
        ('MeanShift', ms),
        ('SpectralClust.', spectral),
        ('Ward', ward),
        ('Agglo.Clust.', average_linkage),
        ('DBSCAN', dbscan),
        ('Birch', birch),
        ('GMM', gmm)
    )

    for name, algorithm in clustering_algorithms:
        t0 = time.time()

        # catch warnings related to kneighbors_graph
        with warnings.catch_warnings():
            warnings.filterwarnings(
                "ignore",
                message="the number of connected components of the " +
                "connectivity matrix is [0-9]{1,2}" +
                " > 1. Completing it to avoid stopping the tree early.",
                category=UserWarning)
            warnings.filterwarnings(
                "ignore",
                message="Graph is not fully connected, spectral embedding" +
                " may not work as expected.",
                category=UserWarning)
            algorithm.fit(X)

        t1 = time.time()
        if hasattr(algorithm, 'labels_'):
            y_pred = algorithm.labels_.astype(np.int)
        else:
            y_pred = algorithm.predict(X)

        plt.subplot(len(datasets), len(clustering_algorithms), plot_num)
        if i_dataset == 0:
            plt.title(name, size=18)

        colors = np.array(list(islice(cycle('bgrcmyk'),
                                      int(max(y_pred) + 1))))
        plt.scatter(X[:, 0], X[:, 1], s=10, color=colors[y_pred])

        plt.xlim(-2.5, 2.5)
        plt.ylim(-2.5, 2.5)
        plt.xticks(())
        plt.yticks(())
        plt.text(.99, .01, ('%.2fs' % (t1 - t0)).lstrip('0'),
                 transform=plt.gca().transAxes, size=15,
                 horizontalalignment='right')
        plot_num += 1
{% endhighlight %}

## Commentary
I really like this plot and I think the addition of the Anisotropically and
varying-variance datasets in the third and fourth rows tells a better story.

### Convex Clusters
The plot clearly shows how well GMMs perform for convex clusters that are
distinct.  GMM is the only algorithm able to properly cluster the
Anisotropically dataset, which is not something I would have expected.

DBSCAN is also a consistent high performer and has the advantage of not
requiring the number of clusters be an input to the algorithm.  This helps for
the "no structure" dataset in the bottm row where there is ony one cluster.
DBSCAN fails for the varying-variance dataset because DBSCAN clusters based on
areas of similar density.

### Non-Convex Clusters
The "noisy circles" and the "noisy moons" datasets in the first two rows are the
non-convex datasets. GMM does poorly on both of these.  This is because the
underlying concept of GMM clustering is to model the clusters as a bunch of
realizations from a Gaussian random variable and Guassians have convex level
curves and will never fit a non-convex shape well.

### Agglomerative Clustering
Agglomerative Clustering is another consistent high performer handling both
convex and non-convex clusters well.  The drawback with Agglomerative Clustering
is that it is way slower than DBSCAN or GMM.

### K-Means Clustering
The plot shows that K-Means--arguably the most popular default clustering
algorithm--is fast, but is also a consistently bad performer.  It doesn't handle
non-convex clusters and it also does not handle clusters that are not well
separated.  K-Means has the further drawback that you have to specify the number
of clusters as an input to the algorithm.


{% highlight python %}

{% endhighlight %}
<hr><br />
[Source Notebook File](https://github.com/gte620v/gte620v.github.io/tree/master/_ipynb/2017-02-27-Comparing_Clustering_Algorithms.ipynb)