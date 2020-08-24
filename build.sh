#!/bin/bash

# model api
oc new-app quay.io/gkrumbach07/nachless:latest-6~https://github.com/Gkrumbach07/solar_forecaster \
	--build-env S2I_SOURCE_NOTEBOOK_LIST=03-model-training.ipynb \
	--name=model

oc expose svc/model
MODEL_URL=http://$(oc get route/model -o jsonpath='{.spec.host}')

# backend
oc new-app centos/python-36-centos7~https://github.com/Gkrumbach07/openshift-flask-api.git \
	-e API_KEY=D0nTsT3Almyk3y \
	-e REACT_APP_MODEL_URL=$MODEL_URL \
	--name=backend

oc expose svc/backend
BACKEND_URL=http://$(oc get route/backend -o jsonpath='{.spec.host}')

# front end
oc new-app nodeshift/ubi8-s2i-web-app:latest~https://github.com/Gkrumbach07/solar-forecaster-web-app.git \
	--build-env REACT_APP_BACKEND_URL=$BACKEND_URL \
	--name=client
oc expose svc/client


# Kafka producer
oc create serviceaccount py-cron

oc create role pod-lister --verb=list --resource=pods,namespaces
oc policy add-role-to-user pod-lister --role-namespace=py-cron system:serviceaccounts:py-cron:py-cron

oc create imagestream py-cron

oc create -f https://raw.githubusercontent.com/Gkrumbach07/kafka-openshift-python-emitter/master/buildConfig.yml

oc set env BuildConfig/py-cron KAFKA_BROKERS=my-cluster-kafka-brokers:9092
oc set env BuildConfig/py-cron KAFKA_TOPIC=forecast
oc set env BuildConfig/py-cron USER_FUNCTION_URI=https://github.com/Gkrumbach07/kafka-openshift-python-emitter/blob/master/examples/emitter.py

oc start-build BuildConfig/py-cron

oc create -f https://raw.githubusercontent.com/Gkrumbach07/kafka-openshift-python-emitter/master/cronJob.yml


# Kafka consumer
oc new-app centos/python-36-centos7~https://github.com/Gkrumbach07/flask-kafka-openshift-python-listener.git \
  -e KAFKA_BROKERS=my-cluster-kafka-brokers:9092 \
  -e KAFKA_TOPIC=forecast\
  --name=listener

oc expose svc/listener
