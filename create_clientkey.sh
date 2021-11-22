#!/bin/bash
#Modified by Rahona Labs, original script at https://github.com/beenje/pi_openvpn/blob/master/roles/openvpn/templates/create_clientside.j2


function init_clientside {
  cd /etc/openvpn/easy-rsa
  . /etc/openvpn/easy-rsa/vars
}


function create_ovpn {
  typeset client=$1

  cd /etc/openvpn/easy-rsa
  cat /etc/openvpn/client.conf \
      <(echo -e '<ca>') \
      keys/ca.crt \
      <(echo -e '</ca>\n<cert>') \
      <(sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' keys/${1}.crt) \
      <(echo -e '</cert>\n<key>') \
      keys/${1}.key \
      <(echo -e '</key>') \
      > ${1}.ovpn
}


function create_client {
  typeset client=$1

  cd /etc/openvpn/easy-rsa
  ./pkitool ${client}
  create_ovpn $client
}


init_clientside
create_client $1

