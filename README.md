# Camel Route Template multi-JVM demo

Demonstrates two independent Spring Boot executable JARs/JVMs using one shared Apache Camel Route Template.

- Red Hat build of Apache Camel: `4.18.4.redhat-00008`
- Spring Boot: `3.5.16`
- Java: `21`

## Build

```bash
mvn clean package
```

## Run in separate terminals

```bash
java -jar app-a/target/app-a-1.0.0.jar
java -jar app-b/target/app-b-1.0.0.jar
```

## Verify

```bash
curl http://localhost:8081/hello
curl http://localhost:8082/hello
```

Responses should have different `pid` values. Stop one process and verify the other remains available.

> This is a sample project, not yet validated by a successful Maven build or runtime test. Each application includes the same shared template module, but creates its own templated route and runs in a separate JVM.
