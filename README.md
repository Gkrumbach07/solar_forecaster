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
These next steps use this model for a few example applications, but this model can be used like any other REST API.
## Web Application
This will be a single page application using React. We will still want to set up a backend to clean up any computations that would of had to been done in the front end.
### Backend
 First we deploy the [back end](https://github.com/Gkrumbach07/openshift-flask-api) which is a simple Flask server. Follow the link to the backend git repo and follow through the steps to deploy the backend to OpenShift. Make sure the name used for the service is *backend*.
### Front End
The front end of the web application uses React and only takes two parameter to set up, name and backend url. Follow the [link](https://github.com/Gkrumbach07/solar-forecaster-web-app/blob/master/README.md) to the front end git repo and follow through the steps to deploy it to OpenShift. Make sure the name used is *client*.
## Kafka Streaming
The next example application is a Kafka streaming service. This will consists of a Kafka producer, consumer, and a Strimzi operator.
### Strimzi
First we need to deploy Strimzi and the best way to do this in OpenShift 4 is to use the the web console. In the web console, navigate to the operators tab and search for the Strimzi operator. Install the operator and deploy the *Kafka* instance using the default settings.
### Kafka Producer
Next we create the Kafka producer. We will use a cron-job to accomplish this. We will run through a series of commands to create the build config and cron config files. First we need to create a service account that will run the cron job. The full in depth process can be found [here](https://github.com/clcollins/openshift-cronjob-example), but the following commands are all that is needed to deploy.
```
oc create serviceaccount py-cron

oc create role pod-lister --verb=list --resource=pods,namespaces
oc policy add-role-to-user pod-lister --role-namespace=py-cron system:serviceaccounts:py-cron:py-cron
```
Next we need to create the S2I build config. This file is available in the [git repo](https://github.com/Gkrumbach07/kafka-openshift-python-emitter) if changes need to be made or if you would like to customize the kafka producer.
```
oc create imagestream py-cron

oc create -f https://raw.githubusercontent.com/Gkrumbach07/kafka-openshift-python-emitter/master/buildConfig.yml
```
Here we set the environment variables. Be sure to set the `KAFKA_BROKERS` variable to the cprrect name. This name can be found in the resources tab of the Strimzi operator's instance. It will be a service where its name ends in *brokers*.
```
oc set env BuildConfig/py-cron KAFKA_BROKERS=__INSERT_KAFKA_BROKER__:9092
oc set env BuildConfig/py-cron KAFKA_TOPIC=forecast
oc set env BuildConfig/py-cron USER_FUNCTION_URI=https://github.com/Gkrumbach07/kafka-openshift-python-emitter/blob/master/examples/emitter.py
```
Then run the command to start the build and create the cron-job. You may edit the cron-job config file to change how often it will run.
```
oc start-build BuildConfig/py-cron

oc create -f https://raw.githubusercontent.com/Gkrumbach07/kafka-openshift-python-emitter/master/cronJob.yml
```
### Kafka Consumer
Finally we can deploy the Kafka consumer which will read the Kafka topic, in the exmaple it is *forecast*, and expose that for Prometheus. Make sure you use the same Kafka broker and topic name for the environment variables. You can find more infomation on this in the [git repo](https://github.com/Gkrumbach07/flask-kafka-openshift-python-listener). Then we expose the listener so Prometheus can find it.
```
oc new-app centos/python-36-centos7~https://github.com/Gkrumbach07/flask-kafka-openshift-python-listener.git \
  -e KAFKA_BROKERS=__INSERT_KAFKA_BROKER__:9092 \
  -e KAFKA_TOPIC=forecast\
  --name=listener

oc expose svc/listener
```
### Wrapping up
Now you can [deploy](https://www.robustperception.io/openshift-and-prometheus) an instance of Prometheus to OpenShift and have it listen to the route you just exposed. First we need to create and expose prometheus. The next steps can be found in the link but for ease of use they are outlined below.
```
oc new-app prom/prometheus
oc expose service prometheus
```
Next we will create the ConfigMap that Prometheus will use. This is where we put the url for our Kafka listener service we made in the last step. You can get this url by using the `oc get routes` and noting the *listener* host. Plug this into the following command.
```
cat <<'EOF' > prometheus.yml
global:
  scrape_interval:     5s 
  evaluation_interval: 5s 

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090', '__LISTENER_HOST_URL__']
      
EOF

oc create configmap prom-config-example --from-file=prometheus.yml
```
Next we'll need to edit the deployment configuration for Prometheus to include this ConfigMap.
```
oc edit dc/prometheus
```
There's two parts we need to add in here.

The first is a new volume name with our ConfigMap and the second is the volumeMount which will give the path of where the prometheus.yml file will be.

First let's add the new volume:
```
 - name: prom-config-example-volume
   configMap:
     name: prom-config-example
     defaultMode: 420
```
Now we'll add the new volumeMount:

```
- name: prom-config-example-volume
  mountPath: /etc/prometheus/
```
Once saved, Prometheus should be up and running and scrapping metrics.
