# Camel Route Template: 独立JAR・独立JVM検証

## 1. 意図と目的

Apache CamelのRoute Templateは、共通のルート構造からパラメータの異なるルートを生成する機能です。**Route TemplateそのものはJARやJVMを分割しません。** 本サンプルでは、共通テンプレートをMavenの共有モジュールとして提供し、**app-aとapp-bをそれぞれ実行可能JARとしてビルドして別JVMで起動**する「方式B」を検証します。

Fuse on KarafのOSGiバンドルからCamel on Spring Bootへの移行に際し、共通化と実行単位の分離を両立できるかを確認するための最小構成です。**1ルート＝1JARをCamelが自動生成する例ではありません。** このサンプルでは各アプリが1つずつRoute Templateを実体化します。

### 検証したいこと

1. 1つの共通Route Templateを複数のSpring Bootアプリから再利用できる。
2. app-aとapp-bを個別の実行可能JARにパッケージングできる。
3. 各JARを別プロセス（別JVM）として起動できる。
4. それぞれのCamelContextに独立したルートが登録される。
5. 一方のプロセスを停止しても、他方が応答を継続する。

## 2. 使用技術

| 項目 | バージョン |
|---|---|
| Red Hat build of Apache Camel | **4.18.4.redhat-00008** |
| Spring Boot | 3.5.16 |
| Java | 21 |
| Maven | 3.9系を推奨 |
| Route DSL | Java DSL |
| HTTP consumer | camel-platform-http-starter / Spring Boot Web |
| Test | JUnit 5 / Spring Boot Test / Maven Surefire |

**注意:** Spring Boot **4** ではなく **3.5.16** を採用しています。指定されたRed Hat Camelバージョンと組み合わせたサンプルです。依存関係の実際の解決・動作は環境で確認してください。Red Hat Mavenリポジトリへのアクセスが必要です。

## 3. アーキテクチャと実装

```text
Maven reactor: route-template-demo
├── common/  (library JAR)
│   └── CommonTemplate.java
│       routeTemplate("hello-template")
│       parameters: label, path
├── app-a/   (Spring Boot executable JAR)
│   ├── Application.java  → route-a / APP-A / /hello
│   └── application.properties  → server.port=8081
└── app-b/   (Spring Boot executable JAR)
    ├── Application.java  → route-b / APP-B / /hello
    └── application.properties  → server.port=8082

JVM-A: app-a.jar + common → CamelContext-A → route-a
JVM-B: app-b.jar + common → CamelContext-B → route-b
```

### common: テンプレートの定義

`common/src/main/java/demo/common/CommonTemplate.java` は `RouteBuilder` の `routeTemplate("hello-template")` を宣言します。`label` と `path` がテンプレートパラメータです。

- `from("platform-http:{{path}}")`: HTTPエンドポイントを定義します。
- `setBody(simple("route={{label}}"))`: 呼び出し元のアプリ名を応答に含めます。
- `ProcessHandle.current().pid()`: 現在のJVMプロセスIDを応答に追加します。

### app-a / app-b: テンプレートの実体化

各アプリケーションは `@SpringBootApplication(scanBasePackages=...)` で共通テンプレートを検出し、`templatedRoute("hello-template")` を呼び出します。

| 項目 | app-a | app-b |
|---|---|---|
| routeId | `route-a` | `route-b` |
| label | `APP-A` | `APP-B` |
| path | `/hello` | `/hello` |
| server.port | 8081 | 8082 |

同じパスでもHTTPポートとJVMが異なるため衝突しません。共通モジュールのコードは両方のJARに依存ライブラリとして取り込まれ、実行時には各JVMで別々に初期化されます。

### ビルド構成

親 `pom.xml` は `common`、`app-a`、`app-b` の3モジュールを宣言します。Camel BOM `4.18.4.redhat-00008` とSpring Boot BOMで依存関係を管理し、各アプリの `spring-boot-maven-plugin` が実行可能JARを生成します。

## 4. 前提条件

- JDK 21（`java -version`）
- Maven 3.9系（`mvn -version`）
- `curl`、`bash`
- Maven CentralおよびRed Hat Mavenリポジトリにアクセス可能
- TCP 8081/8082が未使用

## 5. 取得・ビルド・テスト

```bash
git clone https://github.com/keijijin/camel-route-template-demo-sample.git
cd camel-route-template-demo-sample

java -version
mvn -version

# テストを実行し、2つのJARを作成
mvn clean verify
```

期待される成果物：

```text
app-a/target/app-a-1.0.0.jar
app-b/target/app-b-1.0.0.jar
```

**Maven依存解決エラーの場合**、まず指定バージョンのCamel BOMとstarterが利用可能か、Red Hatリポジトリへの接続・認証・社内プロキシを確認してください。別バージョンへ黙って置き換えないでください。

## 6. 起動方法

ターミナルA:

```bash
java -jar app-a/target/app-a-1.0.0.jar
```

ターミナルB:

```bash
java -jar app-b/target/app-b-1.0.0.jar
```

2つの `java -jar` は独立したOSプロセスとして起動します。停止するには各ターミナルで `Ctrl+C` を押します。

## 7. 手動確認方法

```bash
curl -i http://localhost:8081/hello
curl -i http://localhost:8082/hello
```

期待例（PIDは実行環境で異なります）：

```text
HTTP/1.1 200
...
route=APP-A, pid=12345

HTTP/1.1 200
...
route=APP-B, pid=12346
```

確認ポイント：

1. 両方ともHTTP 200で応答する。
2. 8081は `APP-A`、8082は `APP-B` を返す。
3. **PIDが異なる**ことから別プロセス・別JVMと判定できる。
4. app-aを停止後、8082は応答を継続し、8081は応答しなくなる（他プロセスがポートを使用していない場合）。

プロセス一覧の例：

```bash
jps -lv
ps -ef | grep '[j]ava'
```

## 8. 自動テスト

### JUnit統合テスト

`app-a/src/test/java/demo/appa/ApplicationIntegrationTest.java` と `app-b/src/test/java/demo/appb/ApplicationIntegrationTest.java` で次を検証します。

| テスト | 期待結果 |
|---|---|
| `templatedRouteIsRegistered` | CamelContextに対象routeIdが存在し、ルート数が1 |
| `httpEndpointRespondsWithLabelAndPid` | HTTP 200、正しいAPPラベル、数値PID |
| `unknownEndpointReturnsNotFound` | 未定義パスがHTTP 404 |

`@SpringBootTest(webEnvironment=RANDOM_PORT)` で各アプリのコンテキストを起動します。JUnitのテストは**JVM分離そのものの証明ではありません**。

```bash
mvn test
# または
mvn -pl app-a -am test
mvn -pl app-b -am test
```

### 独立JVM・障害隔離スモークテスト

`scripts/verify-multi-jvm.sh` は、2つのJARを別プロセスで起動し、HTTP応答とPIDを照合した後、app-aを停止してapp-bの応答継続を検証します。

```bash
mvn clean verify
bash scripts/verify-multi-jvm.sh
```

成功時の想定表示：

```text
Independent JVMs confirmed: A=12345 B=12346
Isolation confirmed: app-b still responds after app-a stops
```

スクリプトは終了時に起動したプロセスを停止します。既に8081/8082が使われている場合は実行しないでください。

## 9. 本サンプルの限界・発展

- **Java DSL版**です。XML DSLでのRoute Template共有は別途検証が必要です。
- Route Templateの変更を反映するには、依存するアプリケーションの再ビルドと再デプロイが必要です。
- 各JVMは独立したCamelContextを持つため、メモリ、Bean、`direct:` の呼び出し先は共有しません。
- HTTP、JMS、Kafkaなどを介したJVM間連携は別設計です。
- 障害隔離はプロセス単位ですが、ホスト障害や共有外部システムの障害までは隔離できません。
- 本サンプルにはCI、性能試験、コンテナ化、運用監視は含まれません。

## 10. 検証ステータス

ソースコード・JUnit統合テスト・2プロセスのスモークテストを登録しています。**実際のMavenビルド、JUnit実行、2JVM起動は未実施です。** `mvn clean verify` と `bash scripts/verify-multi-jvm.sh` の結果をもって動作確認してください。
