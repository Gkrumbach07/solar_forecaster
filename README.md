# Solar Forecaster
This notebook is intended to be a first step in gathering data for a solar energy forecasting model. The final dataset will consist of hourly weather data and matching hourly solar data for multiple weather stations. This dataset can then be used for analytical analysis or to train a machine learning model.

## Install the prerequisites

1. Python 3.7 is required to be installed. It can be downloaded from [python.org](https://www.python.org/downloads/).
2. `git` is required to be installed. It can be downloaded from [git-scm.com](https://git-scm.com/downloads).
3. Pipenv is is required to be installed. Instructions can be found [here](https://pypi.org/project/pipenv/).

## Install the notebooks and dependencies

1.  Clone this repository:  `git clone https://github.com/Gkrumbach07/solar_forecaster.git`
2.  Change to this repository's directory:  `cd solar_forecaster`
3.  Install the dependencies:  `pipenv install`
4.  Run the notebooks:  `pipenv run jupyter notebook`

# Deploy to Openshift
If you want to deploy the model as a REST API you can use [nauchless](https://github.com/Gkrumbach07/nachlass). This tool uses the S2I build strategy and can be deployed with a small number of commands.
```
oc new-app quay.io/gkrumbach07/nachless:latest-6~https://github.com/Gkrumbach07/solar_forecaster \
	--build-env S2I_SOURCE_NOTEBOOK_LIST=03-model-training.ipynb \
	--name=model

oc expose svc/model
```
# Further Depolyment
These next steps use this model for a few example applications, but this model can be used like any other REST api.
## Web Application
This will be a single page application run React. We will still want to set up a backend to clean up any computations that would of had to been done in the front end.
### Backend
 First we deploy the [back end](https://github.com/Gkrumbach07/openshift-flask-api) which is a simple Flask server. Follow the link to the backend git repo and follow through the steps to deploy the backend to OpenShift. Make sure the name used for the service is *backend*.
### Front End
The front end of the web application uses React and only takes two parameter to set up, name and backend url. Follow the [link](https://github.com/Gkrumbach07/solar-forecaster-web-app/blob/master/README.md) to the front end git repo and follow through the steps to deploy it to OpenShift. Make sure the name used is *client*.
