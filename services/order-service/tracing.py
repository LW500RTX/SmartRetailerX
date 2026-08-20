import os

def setup_opentelemetry_tracing(service_name: str, app=None):
    """
    Sets up OpenTelemetry TracerProvider, exports traces to Jaeger (jaeger:4317 / OTLP),
    and instruments FastAPI application and outbound HTTP requests.
    """
    try:
        from opentelemetry import trace
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor
        from opentelemetry.sdk.resources import Resource, SERVICE_NAME
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
        from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
        from opentelemetry.instrumentation.requests import RequestsInstrumentor

        jaeger_host = os.getenv("JAEGER_HOST", "jaeger")
        jaeger_port = int(os.getenv("JAEGER_PORT", "4317"))

        resource = Resource.create({SERVICE_NAME: service_name})
        provider = TracerProvider(resource=resource)

        try:
            exporter = OTLPSpanExporter(
                endpoint=f"{jaeger_host}:{jaeger_port}",
                insecure=True
            )
            provider.add_span_processor(BatchSpanProcessor(exporter))
        except Exception as exp_err:
            print(f"[{service_name}] OTLP Jaeger exporter notice: {exp_err}")

        trace.set_tracer_provider(provider)

        if app:
            FastAPIInstrumentor.instrument_app(app, tracer_provider=provider)
        
        RequestsInstrumentor().instrument()
        print(f"[{service_name}] OpenTelemetry distributed tracing initialized successfully.")
        return provider
    except Exception as e:
        print(f"[{service_name}] OpenTelemetry tracing initialization notice: {e}")
        return None
