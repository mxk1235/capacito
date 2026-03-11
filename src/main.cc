#include <grpcpp/grpcpp.h>
#include <grpcpp/ext/proto_server_reflection_plugin.h>
#include <iostream>
#include <memory>
#include <string>

// TODO: Include your generated headers and service implementation once defined
// #include "capacito.grpc.pb.h"
// #include "capacito/capacito_service_impl.h"

void RunServer(const std::string& address) {
    grpc::reflection::InitProtoReflectionServerBuilderPlugin();
    grpc::ServerBuilder builder;

    builder.AddListeningPort(address, grpc::InsecureServerCredentials());

    // TODO: Register your service implementation once defined
    // CapacitoServiceImpl service;
    // builder.RegisterService(&service);

    std::unique_ptr<grpc::Server> server(builder.BuildAndStart());
    std::cout << "[capacito] Server listening on " << address << std::endl;
    server->Wait();
}

int main(int argc, char** argv) {
    const std::string address = "0.0.0.0:50051";
    RunServer(address);
    return 0;
}
