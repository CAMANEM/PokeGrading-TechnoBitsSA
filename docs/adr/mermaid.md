graph TD

    %% =========================
    %% CAPAS
    %% =========================

    subgraph Presentation_Layer["Capa de Presentación"]
        UI[Register ]
        AdminUI[Admin Dashboard / HITL Tools]
    end

    subgraph Services_Layer["Capa de Servicios / Orquestación"]
        Gateway[API Gateway / Auth]
        Orchestrator[Evaluation Orchestrator]
    end

    subgraph Business_Layer["Capa de Negocio (Dominio)"]
        direction TB

        subgraph ID_Engine["Motor de Identificación"]
            FastSearch[Rapid Search - Hashes]
            SpecSearch[Specialized Search]
            DiscoveryProxy[Discovery API Connector]
        end

        subgraph Grading_Engine["Motor de Scoring"]
            PreProc[Image Pre-processor]
            VisionAnalytic[Feature Extractor ROI]
            Heuristics[Scoring Heuristics vN]
        end

        subgraph Market_Engine["Inteligencia de Mercado"]
            MarketProxy[PokeMarket Resilient Proxy]
            Recommender[Economic Recommendation Engine]
        end
    end

    subgraph Data_Access_Layer["Capa de Acceso a Datos / Persistencia"]
        CatalogRepo[Catalog Repository]
        EvalRepo[Evaluation Inmutable Log]
        BlobManager[Image Storage Manager]
    end

    subgraph Data_Layer["Fuentes de Datos / Externos"]
        DB_Catalog[(Reference Catalog DB)]
        DB_Eval[(Evaluations DB)]
        Storage[(Image Blob Storage)]
        PokeMarketAPI{PokeMarket API}
    end

    %% =========================
    %% RELACIONES
    %% =========================

    UI --> Gateway
    AdminUI --> Gateway

    Gateway --> Orchestrator

    Orchestrator --> ID_Engine
    Orchestrator --> Grading_Engine
    Orchestrator --> Market_Engine

    ID_Engine --> CatalogRepo
    Grading_Engine --> BlobManager
    Market_Engine --> PokeMarketAPI

    CatalogRepo --> DB_Catalog
    EvalRepo --> DB_Eval
    BlobManager --> Storage

    %% =========================
    %% PALETA DARK MODE SUAVE
    %% =========================

    classDef presentation fill:#1E293B,stroke:#60A5FA,color:#E2E8F0,stroke-width:2px;
    classDef services fill:#132A24,stroke:#34D399,color:#E2E8F0,stroke-width:2px;
    classDef business fill:#2A1E3F,stroke:#C084FC,color:#F1F5F9,stroke-width:2px;
    classDef dataaccess fill:#3A2A1C,stroke:#F59E0B,color:#F8FAFC,stroke-width:2px;
    classDef datasource fill:#3B1F29,stroke:#FB7185,color:#F8FAFC,stroke-width:2px;

    %% =========================
    %% ASIGNACIÓN
    %% =========================

    class UI,AdminUI presentation;
    class Gateway,Orchestrator services;

    class FastSearch,SpecSearch,DiscoveryProxy business;
    class PreProc,VisionAnalytic,Heuristics business;
    class MarketProxy,Recommender business;

    class CatalogRepo,EvalRepo,BlobManager dataaccess;

    class DB_Catalog,DB_Eval,Storage,PokeMarketAPI datasource;

    %% =========================
    %% SUBGRAPHS
    %% =========================

    style Presentation_Layer fill:#0F172A,stroke:#60A5FA,stroke-width:2px,color:#F8FAFC
    style Services_Layer fill:#0B1F1A,stroke:#34D399,stroke-width:2px,color:#F8FAFC
    style Business_Layer fill:#1B132B,stroke:#C084FC,stroke-width:2px,color:#F8FAFC
    style Data_Access_Layer fill:#24180F,stroke:#F59E0B,stroke-width:2px,color:#F8FAFC
    style Data_Layer fill:#2A131B,stroke:#FB7185,stroke-width:2px,color:#F8FAFC

    %% =========================
    %% LINKS
    %% =========================

    linkStyle default stroke:#64748B,stroke-width:1.7px