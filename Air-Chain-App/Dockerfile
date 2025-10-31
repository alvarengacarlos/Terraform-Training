FROM maven:3.9.9-amazoncorretto-23-alpine AS backend-build
ARG DB_PASSWORD
ARG DB_ENDPOINT
WORKDIR /backend
COPY backend .
COPY scripts/backend scripts
COPY backend-appspec.yml appspec.yml
RUN sed -i "s|spring.datasource.url=.*|spring.datasource.url=jdbc:mysql://root:$DB_PASSWORD@$DB_ENDPOINT/air_chain_backend_db|" src/main/resources/application.properties
RUN mvn clean install
RUN cp target/backend-*.jar backend.jar
RUN tar -czvf backend.tar.gz backend.jar migrations appspec.yml scripts

FROM node:22 AS frontend-build
WORKDIR /frontend
COPY frontend .
COPY scripts/nginx scripts
COPY frontend-appspec.yml appspec.yml
RUN tar -czvf frontend.tar.gz *

FROM alpine:latest AS final
WORKDIR /artifacts
COPY --from=backend-build /backend/backend.tar.gz .
COPY --from=frontend-build /frontend/frontend.tar.gz .