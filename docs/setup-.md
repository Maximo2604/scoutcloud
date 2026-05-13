bash scripts/setup-check.sh
== Shell ==
  [32mOK  [0m  bash 3.2.57(1)-release
== git ==
  [32mOK  [0m  git 2.39.2
== python3 ==
  [31mFAIL[0m  python3 3.9.6 (need >= 3.10)
== pip3 ==
  [32mOK  [0m  pip3 21.2.4
== terraform ==
  [32mOK  [0m  terraform 1.15.2
== docker ==
  [32mOK  [0m  docker 29.4.3
  [31mFAIL[0m  docker daemon is NOT running (start Docker Desktop or systemctl start docker)
== aws cli ==
  [32mOK  [0m  aws-cli 2.34.11
  [32mOK  [0m  aws credentials configured
== kubectl ==
  [31mFAIL[0m  kubectl not installed
== ansible ==
  [31mFAIL[0m  ansible not installed
== make ==
  [32mOK  [0m  make 3.81
== curl ==
  [32mOK  [0m  curl 8.7.1

== Summary ==
  Passed: 9
  Failed: 4
make: *** [setup] Error 1
