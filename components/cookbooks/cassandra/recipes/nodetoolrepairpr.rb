#
# Cookbook Name:: cassandra
# Recipe:: nodetoolrepairpr
#
# Copyright 2014, Prana
#
# All rights reserved - Do Not Redistribute
execute "/opt/cassandra/bin/nodetool repair -pr"
