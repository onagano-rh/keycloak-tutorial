<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [用意するもの](#用意するもの)
    - [Serverディストリビューションの解凍](#serverディストリビューションの解凍)
- [StandaloneモードでのKeycloakサーバの起動](#standaloneモードでのkeycloakサーバの起動)
    - [管理ユーザについての注意事項](#管理ユーザについての注意事項)
    - [WildFlyの管理コンソールについて](#wildflyの管理コンソールについて)
    - [Keycloakが使用するデータベースについての注意事項](#keycloakが使用するデータベースについての注意事項)
        - [PostgreSQLのDockerイメージを使う例](#postgresqlのdockerイメージを使う例)
- [DomainモードでのKeycloakサーバの起動](#domainモードでのkeycloakサーバの起動)
    - [ドメインを複数のホストで構成する場合の注意事項](#ドメインを複数のホストで構成する場合の注意事項)
    - [デフォルトのドメイン構成の概観](#デフォルトのドメイン構成の概観)
    - [Masterホストにおけるserver-twoの追加](#masterホストにおけるserver-twoの追加)
    - [HTTPアクセスログの有効化](#httpアクセスログの有効化)
    - [Request Dumperの有効化](#request-dumperの有効化)
    - [クラスタリングのプロトコルのデフォルトUDPからTCPへの変更](#クラスタリングのプロトコルのデフォルトudpからtcpへの変更)
- [アプリケーションの準備](#アプリケーションの準備)
    - [サンプルアプリのコピー](#サンプルアプリのコピー)
    - [アプリケーションサーバの準備とクライアントアダプタのインストール](#アプリケーションサーバの準備とクライアントアダプタのインストール)
- [サンプルアプリを使ったOIDCによるSSO設定のチュートリアル](#サンプルアプリを使ったoidcによるsso設定のチュートリアル)
    - [Keycloakサーバでのレルムの作成](#keycloakサーバでのレルムの作成)
    - [APIサーバのクライアント登録:](#apiサーバのクライアント登録)
    - [APIサーバを呼び出すWebアプリのクライアント登録](#apiサーバを呼び出すwebアプリのクライアント登録)
    - [発展](#発展)

<!-- markdown-toc end -->


# 用意するもの

- Keycloak本体（Version 4以降のServerディストリビューションのどれか）
  - [Version 4.8.3.Final Server](https://www.keycloak.org/archive/downloads-4.8.3.html)
    - RH-SSO 7.3のベース
  - [Version 9.0.0 Server](https://www.keycloak.org/downloads.html)
    - 2020-03時点の最新バージョン
    - RH-SSO 7.4のベースになる見込み
- Java 8以上のJDK
- オプションでDocker
  - 外部データベースをコンテナで動かす場合に必要
- メモリ4GB以上のLinuxマシン1台
  - Windowsの場合は .sh -> .bat, "/" -> "\\" など、適宜読みかえる事。
  - OSの種類には依存しないのでWindowsでも原則的に実行可能。

## Serverディストリビューションの解凍

ServerディストリビューションのZIPアーカイブを適当な場所に解凍し、
そこを環境変数`SSO_HOME`に設定しておく。

```shell
$ export SSO_HOME=...
$ ls -l $SSO_HOME
total 544
drwxr-x--x. 3 onagano onagano   4096 Jan 15  2019 bin
drwxr-xr-x. 7 onagano onagano   4096 Jan 15  2019 docs
drwxr-x--x. 5 onagano onagano   4096 Jan 15  2019 domain
-rw-r--r--. 1 onagano onagano 479889 Jan 15  2019 jboss-modules.jar
-rw-r--r--. 1 onagano onagano  10637 Jan 15  2019 License.html
-rw-r--r--. 1 onagano onagano  26530 Jan 15  2019 LICENSE.txt
drwxr-xr-x. 3 onagano onagano   4096 Jan 15  2019 modules
drwxr-x--x. 6 onagano onagano   4096 Jan 15  2019 standalone
drwxr-xr-x. 5 onagano onagano   4096 Jan 15  2019 themes
-rw-r--r--. 1 onagano onagano     31 Oct 10  2018 version.txt
drwxr-xr-x. 2 onagano onagano   4096 Jan 15  2019 welcome-content
```

ディスクの節約および迅速な再現環境構築のため、このインストレーションは直接使わず、
Read-Onlyの参照先として複数のサーバインスタンスで共有することにする。
ただし、この起動方法は WFLYSRV0266 の警告ログが出るようにプロダクションではサポートされない。


# StandaloneモードでのKeycloakサーバの起動

必要な設定ファイルをコピーし、それをシステムプロパティ`jboss.server.base.dir`に
指定して起動する。

```shell
$ cp -a $SSO_HOME/standalone ./standalone.sso
$ $SSO_HOME/bin/standalone.sh -Djboss.server.base.dir=./standalone.sso
```

名前に".sso"を付けたのは、今後予定しているAPIサーバ用の"standalone.api"、
それを呼び出すアプリケーション用の"standalone.app"と区別するため。

デフォルトのポート番号を用いて http://localhost:8080/auth/ にアクセスし、
Keycloakの管理ユーザを登録後、自由に使用する。

ポートオフセットを設けたい場合は、例えば100のオフセットを付加するなら、
起動オプションに `-Djboss.socket.binding.port-offset=100` を追加し、ポート 8180 でアクセスする。

その他、localhostではないホストからのアクセスを受け付けるなら、
起動オプション`-b`によってリスンアドレスを指定する。
`$SSO_HOME/bin/standalone.sh --help`も参照。

このサーバインスタンスに関連するファイルは全て"./standalone.sso"以下に保存され、
自由にバックアップや破棄ができる。

## 管理ユーザについての注意事項

初回アクセス時に作成した管理ユーザは、KeycloakのWebアプリの管理者であって、
ベースになっているWildFlyサーバの管理ユーザとは異なる（そもそもレイヤーが違う）。

- Keycloakのユーザ管理
  - Webアプリ /auth で行う
  - データはデータベースに保存される
    - デフォルトではH2データベース、ファイルは"./standalone.sso/data/keycloak.*.db"
- WildFlyのユーザ管理
  - シェルスクリプト $SSO_HOME/bin/add-user.sh で登録する
  - データは ./standalone.sso/configuration/ 配下のプロパティファイルに保存される
  - 以下のユースケースではユーザ登録が必須だが、そうでなければ無しで済ますことも可能
    - WildFlyの管理コンソールを使う
    - リモートから $SSO_HOME/bin/jboss-cli.sh 等で接続する
    - Domainモードで、複数のホストでドメインを構成する
    - Java EE標準の（サーブレットやEJBの配備記述子で設定するような）セキュリティ機能を使う

## WildFlyの管理コンソールについて

WildFlyの操作や設定は、JBoss CLI (jbos-cli.sh) の他に、
GUIの管理コンソール (http://localhost/8080/console) でもできる。
これを使うにはあらかじめWildFlyの管理ユーザを登録しておく必要があり、
そのユーザで上記URLにアクセスし、ログインして使用する。

コピーしたstandalone.ssoやdomain.ssoに対して管理ユーザを登録するには、
以下のようにそれぞれシステムプロパティをJAVA_OPTS環境変数に指定してadd-user.sh
を実行する。引数にユーザ名"admin"とそのパスワード"RedHat1!"も指定している。

```shell
$ JAVA_OPTS="\
  -Djboss.server.config.user.dir=./standalone.sso/configuration \
  -Djboss.domain.config.user.dir=./domain.sso/configuration "\
  ${SSO_HOME}/bin/add-user.sh admin 'RedHat1!'
```

単に`$SSO_HOME/bin/add-user.sh`だけをオプションや引数なしで実行すると、
対話的にユーザ名等を聞かれながら$SSO_HOME以下のファイルに直接ユーザが追加される。
毎回同じ管理ユーザを使うなら、コピー元である$SSO_HOMEに一度だけ追加しておくのもよい。

対話的に聞かれる項目では、管理ユーザかアプリケーションユーザかの項目があるが、
CLIや管理コンソールのユーザについては管理ユーザを、ServletやEJBのユーザについては
アプリケーションユーザを選択する。
ロールについては空でもよい。
最後にリモートホストからの接続に使用するかどうかを"yes/no"で聞かれるが、
Domainモードでリモートホストが接続に使用するユーザの場合はyesを選択するが、
管理コンソールにログインするだけであればnoでよい。

- 参考: 3.2. 管理ユーザー
  - https://access.redhat.com/documentation/ja-jp/red_hat_jboss_enterprise_application_platform/7.2/html/configuration_guide/management_users

## Keycloakが使用するデータベースについての注意事項

Keycloakは"KeycloakDS"と言う名のデータベースが必ず必要。
デフォルトでローカルファイルを使ってJava製RDBのH2がKeycloakサーバと同一のJavaプロセス内で
実行されるようになっている。

本番環境では、$SSO_HOME/modules/以下にJDBCドライバをインストールし、standalone.xml内の
KeycloakDSの設定を適切に変更する必要がある。
これについては[EAPのドキュメント](https://access.redhat.com/documentation/ja-jp/red_hat_jboss_enterprise_application_platform/7.2/html/configuration_guide/datasource_management)を参照。

### PostgreSQLのDockerイメージを使う例

```shell
$ docker run -d --name keycloak-db -e POSTGRES_PASSWORD='postgres' -p 5432:5432 postgres
# sudo dnf install postgresql-jdbc
$ ls /usr/share/java/postgresql-jdbc/postgresql.jar
$ $SSO_HOME/bin/jboss-cli.sh -c
[standalone@localhost:9990 /] module add --name=com.postgresql --resources=/usr/share/java/postgresql-jdbc/postgresql.jar --dependencies=javax.api,javax.transaction.api
[standalone@localhost:9990 /] /subsystem=datasources/jdbc-driver=postgresql:add(driver-name=postgresql,driver-module-name=com.postgresql,driver-xa-datasource-class-name=org.postgresql.xa.PGXADataSource)
[standalone@localhost:9990 /] /subsystem=datasources/data-source=KeycloakDS:remove
[standalone@localhost:9990 /] data-source add --name=KeycloakDS --jndi-name=java:jboss/datasources/KeycloakDS --driver-name=postgresql --connection-url=jdbc:postgresql://localhost:5432/postgres --user-name=postgres --password=postgres --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter
[standalone@localhost:9990 /] :reload
[standalone@localhost:9990 /] /subsystem=datasources/data-source=KeycloakDS:test-connection-in-pool
[standalone@localhost:9990 /] exit
```

データベースがリセットされたので http://localhost:8080/auth にアクセスし直して
再度Keycloakの管理ユーザを登録する。

なお、RH-SSOでは現時点では通常のPostgreSQLはサポートされない。

- 参考: Tested Integrations: Red Hat Single Sign-On 7.3
  - https://access.redhat.com/articles/2342861#Int_7_3


# DomainモードでのKeycloakサーバの起動

ここでも、影響を局所化するために設定ファイルをコピーし、
それをシステムプロパティで指定して起動する。

```shell
$ cp -a $SSO_HOME/domain ./domain.sso
$ $SSO_HOME/bin/domain.sh -Djboss.domain.base.dir=./domain.sso
```

設定ファイルは ./domain.sso/configuration/domain.xml で、
これにプロファイルとサーバグループを設定する。

さらに、そのサーバグループと実際のサーバ（standaloneモードの
サーバインスタンスに相当）をマップするために、
./domain.sso/configuration/host.xml が使われる。
起動オプションに`--host-config`を指定していなければ、
デフォルトでこのhost.xmlが使われる。

## ドメインを複数のホストで構成する場合の注意事項

もし複数台のマシンでドメインを構成するならば、
2台目以降のslaveホストのdomain.shの引数には、
domain.xmlとhost.xmlの組み合わせの代わりに、
masterホストがどこかという情報と
そのホスト用にカスタマイズされたhost.xmlを指定して
起動することになる。
Slaveホストがmasterホストに接続するときにadd-user.sh
で登録したユーザ名とパスワードの情報も必要になる。
詳しくは以下のKCSを参照。

- How to setup EAP in Domain Mode with Remote Host Controllers ?
  - https://access.redhat.com/solutions/218053

## デフォルトのドメイン構成の概観

3つのプロファイルが定義されている。

```shell
$ grep '<profile ' ./domain.sso/configuration/domain.xml
        <profile name="auth-server-standalone">
        <profile name="auth-server-clustered">
        <profile name="load-balancer">
```

サーバグループは2つあり、それぞれ"auth-server-clustered"と
"load-balancer"のプロファイルにマップされている。

```shell
$ grep '<server-group ' ./domain.sso/configuration/domain.xml
        <server-group name="auth-server-group" profile="auth-server-clustered">
        <server-group name="load-balancer-group" profile="load-balancer">
```

host.xmlの方を見てみると、それらのサーバグループに1つずつ
サーバインスタンスが割り当てられている。

```shell
$ grep '<server ' ./domain.sso/configuration/host.xml
        <server name="load-balancer" group="load-balancer-group"/>
        <server name="server-one" group="auth-server-group" auto-start="true">
```

これらの行の前後を見てみると、"load-balancer"はポートオフセット無し、
"server-one"はポートオフセット150に設定されている。
よってポート番号はそれぞれ8080と8230になる。

結果的にdomain.sh実行後には2つのサーバが起動する。

```shell
$ ps -wfH
UID        PID  PPID  C STIME TTY          TIME CMD
onagano  26694 18969  0 14:34 pts/1    00:00:00   /bin/sh /.../domain.sh -Djboss.domain.base.dir=./domain.sso
onagano  26810 26694  0 14:34 pts/1    00:00:02     java -D[Process Controller] ...
onagano  26832 26810  0 14:34 pts/1    00:00:13       java -D[Host Controller] ...
onagano  26930 26810  0 14:34 pts/1    00:00:14       /.../java -D[Server:load-balancer] ...
onagano  27008 26810  2 14:34 pts/1    00:01:08       /.../java -D[Server:server-one] ...
```

"Process Controller"および"Host Controller"はドメイン管理に特化したプロセスで、
Keycloakのサービス提供には直接は関与しない。

load-balancerは、WildFlyのWebサーバコンポーネントであるUndertowが持つリバースプロキシの
機能を使った簡易ロードバランサで、複数のKeycloakサーバからなるクラスタへの単一窓口として使える。
プロダクション環境では別途専用のロードバランサを用意する。

- 参考: 8.3. Setting Up a Load Balancer or Proxy
  - https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.3/html/server_installation_and_configuration_guide/clustering#setting-up-a-load-balancer-or-proxy

なお、初回アクセス時のKeycloakの管理ユーザ登録は間接的なサーバアクセスでは行えないため、
server-oneに直接アクセスする http://localhost:8230/auth にて行う。

## Masterホストにおけるserver-twoの追加

デフォルトのドメイン構成では、別のマシンでhost-slave.xmlを使って
2つめのKeycloakサーバであるserver-twoを起動し、クラスタを構成する想定になっている。
ここでは一台のマシンのみでクラスタの検証環境を構築するため、
masterである現ホストにserver-twoを追加する。

```shell
$ $SSO_HOME/bin/jboss-cli.sh -c
[domain@localhost:9990 /] /host=master/server-config=server-two:add(group=auth-server-group,socket-binding-port-offset=200)
[domain@localhost:9990 /] /host=master/server-config=server-two:start
```

各サーバのserver.logに ISPN000094 のログメッセージで起動したサーバのリストが確認できれば
クラスタの形成に成功している。

```
2020-03-09 15:42:49,844 INFO  [org.infinispan.CLUSTER] (MSC service thread 1-7) ISPN000094: Received new cluster view for channel ejb: [master:server-one|1] (2) [master:server-one, master:server-two]
```

## HTTPアクセスログの有効化

デバッグに有効な情報も含めたHTTPアクセスログを、Keycloakサーバに対して設定する。

```shell
[domain@localhost:9990 /] /profile=auth-server-clustered/subsystem=undertow/server=default-server/http-listener=default:write-attribute(name=record-request-start-time,value=true)
[domain@localhost:9990 /] /profile=auth-server-clustered/subsystem=undertow/server=default-server/host=default-host/setting=access-log:add(pattern="%h %l %u %t \"%r\" %s %b \"%{i,Referer}\" \"%{i,User-Agent}\" Cookie: \"%{i,COOKIE}\" Set-Cookie: \"%{o,SET-COOKIE}\" SessionID: %S Thread: \"%I\" TimeTaken: %T")
[domain@localhost:9990 /] /host=master:reload
```

StandaloneモードのCLIと違う点として、domainモードでは
`/profile=auth-server-clustered`のようにプロファイルを指定するプレフィクスが付く。

- 参考: How to enable access logging for JBoss EAP 7?
  - https://access.redhat.com/solutions/2423311

## Request Dumperの有効化

- 参考: Configure Request logging / RequestDumping handler in JBoss EAP 7
  - https://access.redhat.com/solutions/2429371

## クラスタリングのプロトコルのデフォルトUDPからTCPへの変更

- 参考: How do I switch clustering to TCP instead of multicast UDP in EAP 6?
  - https://access.redhat.com/solutions/140103


# アプリケーションの準備

Keycloakのクイックスタートプロジェクトにあるサンプルアプリを2つ使って
OpenID Connectによる基本的な認証のプロセスを確認する。

- Keycloakのクイックスタートプロジェクト
  - https://github.com/keycloak/keycloak-quickstarts

参考までに、製品版のRH-SSOの関連情報を以下に示す。

- RH-SSOのクイックスタートプロジェクト
  - https://github.com/redhat-developer/redhat-sso-quickstarts/
- Keycloakと、その製品版のRH-SSOのバージョン対応表
  - https://access.redhat.com/solutions/3296901
    - Keycloak 4.y.z が RH-SSO 7.3.z に対応する
    - RH-SSO 7.3.z は EAP 7.2.z に相当する
- KeycloakのベースになっているWildFlyと、その製品版のEAPのバージョン対応表
  - https://access.redhat.com/solutions/21906
    - EAP 7.2.z は WildFly 14.y.z に相当する

## サンプルアプリのコピー

pom.xmlがバージョンに応じて変わるので、適切な版をチェックアウトし、適宜修正する。
クイックスタート内の各プロジェクトは、親ディレクトリのpom.xmlを参照して依存性を
一括管理している。

```shell
$ cd /path/to
$ git clone https://github.com/keycloak/keycloak-quickstarts.git
$ cd keycloak-quickstarts
$ git checkout -b 4.8.3.Final 4.8.3.Final
```

子に相当する各プロジェクトを個別にコピーして使用する場合は、
親のpom.xmlもコピーして階層を合わせる。
今回はAPIサーバ側として service-jee-jaxrs を、
それを利用するWebアプリ側として app-jee-jsp を使用する。
いずれもJava EE標準のWebアプリで最もシンプルな例になる。

```shell
$ cd <このチュートリアルのディレクトリ>
$ cp /path/to/keycloak-quickstarts/pom.xml .
$ cp /path/to/keycloak-quickstarts/service-jee-jaxrs .
$ cp /path/to/keycloak-quickstarts/app-jee-jsp .
```

## アプリケーションサーバの準備とクライアントアダプタのインストール

これらをデプロイするアプリケーションサーバを準備する。
別途WildFlyをダウンロードするのが通常だが、今回はすでにある`$SSO_HOME`で代用する。
ただし、運用環境でKeycloakサーバに通常のアプリをデプロイすることは想定されていない。

- Keycloak 4.8.3.Final のWildFly用の Client Adapter のダウンロード
  - https://www.keycloak.org/archive/downloads-4.8.3.html
- ドキュメント: 2.1.2. JBoss EAP/WildFly Adapter
  - https://www.keycloak.org/docs/4.8/securing_apps/index.html#jboss-eap-wildfly-adapter

```shell
$ unzip keycloak-wildfly-adapter-dist-4.8.3.Final.zip -d $SSO_HOME
$ # 途中ファイルの上書き許可を求められるが、上書きされるのはライセンスのテキストファイル等なので全て許可して問題ない
$ ls $SSO_HOME/modules/system/add-ons
```

アプリケーションを動かす各サーバに、クライアントアダプタがインストールしたCLIスクリプトを用いて
standalone.xmlに適切な変更を加える。
これにより、このサーバ上で動くアプリケーションが、Java EE標準で使えるFROM認証やBASIC認証の他に、
KEYCLOAK認証を使えるようになる。
アダプタを各アプリケーションのライブラリとしてインストールするのではなく、サーバ側に設定することで
そこにデプロイする全てのアプリケーションから使えるようになる。
クイックスタートのアプリもKEYCLOAK認証を用いている。

APIサーバ (standalone.api) をポートオフセット1000で準備してアダプタを設定する。

```shell
$ cp -a $SSO_HOME/standalone standalone.api
$ $SSO_HOME/bin/standalone.sh -Djboss.server.base.dir=./standalone.api -Djboss.socket.binding.port-offset=1000 &
$ $SSO_HOME/bin/jboss-cli.sh --controller=localhost:10990 -c --file=${SSO_HOME}/bin/adapter-elytron-install.cli
```

Webアプリのサーバ (standalone.web) をポートオフセット1100で準備してアダプタを設定する。

```shell
$ cp -a $SSO_HOME/standalone standalone.web
$ $SSO_HOME/bin/standalone.sh -Djboss.server.base.dir=./standalone.web -Djboss.socket.binding.port-offset=1100 &
$ $SSO_HOME/bin/jboss-cli.sh --controller=localhost:11090 -c --file=${SSO_HOME}/bin/adapter-elytron-install.cli
```

以下、下記3台のサーバが起動している状態で話を進める。

| サーバ    | ディレクトリ   | HTTPポート | 管理ポート |
|-----------|----------------|------------|------------|
| Keycloak  | standalone.sso |       8080 |       9990 |
| APIサーバ | standalone.api |       9080 |      10990 |
| Webアプリ | standalone.web |       9180 |      11090 |

Keycloakについてはスタンドアロンモードの代わりにドメインモードを使うこともできる。
その場合domain.ssoディレクトリやdomain.xmlが対象になるが、ポート番号は変わらない。

管理ポートはWildFlyの管理コンソールやJBoss CLIによるアクセスに用いる。
KeycloakそのものはWildFlyにデプロイされているアプリなのでHTTPポートを使う。

| サーバ              | 管理コンソールのURL              |
|---------------------|----------------------------------|
| Keycloakそのもの    | http://localhost:8080/auth/admin |
| Keycloak (WildFly)  | http://localhost:9990/console    |
| APIサーバ (WildFly) | http://localhost:10990/console   |
| Webアプリ (WildFly) | http://localhost:11090/console   |

WildFlyの管理者のユーザ名とパスワードは、全て'admin/RedHat1!'に設定してあり、
standalone.\*/configuration/mgmt-users.properties に保存されている。
ただし、このパスワードはBase64エンコードされているだけで暗号化されているわけではないので注意する。

Keycloakについては初回アクセス時に設定したものがデータベースに保存される。


# サンプルアプリを使ったOIDCによるSSO設定のチュートリアル

## Keycloakサーバでのレルムの作成

1. 管理ユーザでログインしレルム"test-realm"を作成する。
1. Rolesメニューでロール"user"を作成する。
1. Usersメニューでユーザ"testuser01"を作成する。
   作成後にCredentialsタブでパスワードをTemporary: OFFで作成し、
   Role Mappingsタブで作成したロール"user"をアサインする。
1. 同様に、ロール"admin"とユーザ"adminuser01"を作成し、
   ロール"user"と"admin"をアサインする。

- GitHub link: https://github.com/keycloak/keycloak-quickstarts/tree/4.8.3.Final

## APIサーバのクライアント登録:

1. 管理ユーザでログインし"test-realm"を選択する。
1. Clientsメニューでクライアント"service-jee-jaxrs"を作成する。
   Root URLは空でよい。
1. Access Typeを"bearer-only"に設定する。
1. Instllationタブで"Keycloak OIDC JSON"を選択し、keycloak.jsonをダウンロードする。
1. keycloak.jsonを service-jee-jaxrs/config ディレクトリに配置する。
   もともとあったファイル (client-import.json と keycloak-example.json) は削除してもよい。
1. アプリケーションをビルドしAPIサーバにデプロイする。

```shell
$ cd service-jee-jaxrs
$ mvn -Denforcer.skip=true clean package
$ cp target/service.war ../standalone.api/deployments/
```
- デプロイはJBoss CLIやmvnコマンドでもできるが、上記のようにコピーで済ますとstandalone.xmlが変更されない。
- keycloak.jsonはservice.warのWEB-INF/に保存され、Keycloakのクライアントアダプタが読み込む。
- ユーザ名は何でもいいが、ロール名はアプリケーションにハードコードされている (src/main/webapp/WEB-INF/web.xml) ので変えられない。
- このアプリは以下の3つのREST APIを持っている。
  "public"は認証なしでアクセスできるが、"secured"は"user"ロールが、"admin"は"admin"ロールが必要になる。
  - http://localhost:9080/service/public
  - http://localhost:9080/service/secured
  - http://localhost:9080/service/admin

- GitHub link: https://github.com/keycloak/keycloak-quickstarts/tree/4.8.3.Final/service-jee-jaxrs

## APIサーバを呼び出すWebアプリのクライアント登録

1. 管理ユーザでログインし"test-realm"を選択する。
1. Clientsメニューでクライアント"app-jee-jsp"を作成する。
   Root URLには "http://localhost:9180/app-jsp" を設定する。
1. Access Typeを"confidential"に設定する。
1. Instllationタブで"Keycloak OIDC JSON"を選択し、keycloak.jsonをダウンロードする。
1. keycloak.jsonを service-jee-jaxrs/config ディレクトリに配置する。
   もともとあったファイル (client-import.json と keycloak-example.json) は削除してもよい。
1. src/main/java/org/keycloak/quickstart/appjee/ServiceLocator.java でAPIサーバの場所(URL)を決定しているので、
   "http://localhost:9080/service" を指すように変更する。
1. アプリケーションをビルドしAPIサーバにデプロイする。
1. "http://localhost:9180/app-jsp/" にブラウザでアクセスし動作確認する。

```shell
$ cd app-jee-jsp
$ vi src/main/java/org/keycloak/quickstart/appjee/ServiceLocator.java
$ mvn -Denforcer.skip=true clean package
$ cp target/app-jsp.war ../standalone.web/deployments/
```

- Access Typeを"confidential"にしたのでこのクライアントはパスワード(secret)を持っており、keycloak.jsonに含まれている。
  従ってこのファイルは公開できない。
- ServiceLocator.java ではAPIサーバの場所をシステムプロパティや環境変数でも設定できるようになっているが、
  サーバの再起動が必要になるためコードの方を変更する。
- "INVOKE PUBLIC"はログインしなくても呼び出せるが、"INVOKE SECURED"は"testuser01"または"adminuser01"で、
  "INVOKE ADMIN"は"adminuser01"でログインしないと呼び出せないのを確認する。

- GitHub link: https://github.com/keycloak/keycloak-quickstarts/tree/4.8.3.Final/app-jee-jsp

## 発展

- Request Dumperを有効化し、HTTPヘッダ内のトークンを実際に見てみる。
  - helper.sh 内でこれを行う関数を定義しているので、sourceして使ってみる。
- トークンを https://jwt.io/ などでデコードしてみる｡
- レルムの設定で"Access Token Lifespan"や、"SSO Session Idle"、"SSO Session Max"などの値を変えてみる。
