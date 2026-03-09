# Automated Roadmap-to-PRD Decomposition: Research Report

**Research Question:** How should a roadmap be automatically decomposed into independent, well-bounded PRDs with proper dependency management?

**Classification:** Type C (Analysis) | **Date:** 2026-03-01 | **Revision:** 2.0

---

## Executive Summary

This report investigates automated decomposition of product roadmaps into independent, well-bounded Product Requirements Documents (PRDs) with proper dependency management. The research synthesizes evidence from agile methodology literature, graph algorithm theory, domain-driven design, NLP-based dependency detection, and emerging LLM-based decomposition research.

### Key Findings

1. **Vertical slice decomposition is the evidence-backed default.** Multiple independent sources confirm that cutting through all system layers produces independently valuable, demo-able units with lower integration risk than horizontal (layer-based) splitting. [C1 -- verified across Bogard, Cohn/SPIDR, Humanizing Work, SAFe]

2. **LLM-based dependency detection has reached practical accuracy.** The LEREDD system (Feb 2026) achieves 0.93 accuracy and 0.84 F1 on requirement pair dependency classification using RAG + In-Context Learning, but zero-shot LLMs perform poorly on fine-grained dependency types (F1 ~0.30-0.40). [C1 -- arXiv:2602.22456]

3. **Human-AI collaboration is mandatory, not optional.** Industry surveys show 58.2% AI adoption in requirements engineering but only 5.4% full automation. Zero practitioners believe LLMs can handle analysis/validation independently. [C1 -- arXiv:2509.11446, arXiv:2511.01324]

4. **Dependency graphs must be DAGs, validated incrementally.** Kahn's algorithm (O(V+E)) handles topological sort; Tarjan's SCC (O(V+E)) detects cycles. For dynamic updates, Haeupler's incremental algorithm (O(m^{3/2})) maintains ordering as edges are added. [C1 -- standard CS literature]

5. **Validation requires MECE + INVEST + anti-pattern detection.** The 100% rule (WBS standard) ensures completeness; INVEST criteria ensure quality; 10 documented anti-patterns catch common decomposition failures. [C1 -- PMI, Agile Alliance, Humanizing Work]

6. **Bounded-context identification from DDD provides the strongest boundary heuristic.** Microsoft's microservice guidance validates: start with bounded contexts, refine to aggregates, validate against cohesion/coupling metrics. This maps directly to PRD boundary identification. [C2 -- Microsoft Architecture Center]

### Recommended Architecture

```
Roadmap Input (markdown/YAML)
    |
[1. Parse & Classify] --> Roadmap items with metadata
    |
[2. Strategy Selection] --> SPIDR technique per item
    |
[3. LLM Decomposition] --> Draft PRDs (few-shot + template + reasoning)
    |
[4. Dependency Extraction] --> Explicit + implicit dependency pairs
    |
[5. DAG Construction] --> Validated acyclic dependency graph
    |
[6. INVEST Scoring] --> Quality scores per PRD (0.0-1.0)
    |
[7. Anti-Pattern Detection] --> Flag violations (10 patterns)
    |
[8. MECE Validation] --> Completeness & overlap check
    |
[9. Confidence Calculation] --> Aggregate confidence score
    |
[10. Human Review Gate] --> Mandatory if confidence < 0.7
    |
Final PRDs + Validated DAG + Execution Order
```

---

## 1. Decomposition Strategies

### 1.1 Vertical Slice Decomposition (Evidence Grade: A)

Vertical slice decomposition cuts through all layers of the application -- from user interface through business logic to database -- to deliver a thin but complete piece of functionality.

**Definition (Bogard):** "Instead of coupling across a layer, we couple vertically along a slice. Minimize coupling between slices, and maximize coupling in a slice."

**Why vertical slices win for automated decomposition:**

| Benefit | Mechanism | Implication for Automation |
|---------|-----------|---------------------------|
| Faster feedback | Each slice is demo-able | Validates decomposition early |
| Reduced integration risk | Integration happens per slice | No deferred "big bang" merge |
| Parallel development | Slices are isolated | Multiple agents work simultaneously |
| Value delivery | Each slice has user value | Satisfies INVEST "V" criterion |
| Natural boundaries | Slice = bounded functionality | Maps to PRD scope |

**When horizontal slicing is acceptable:**
- Sprint 0 architecture setup (foundational layer)
- Well-understood interfaces with clear layer contracts
- Specialist leverage where horizontal work parallelizes cleanly

**Recommendation for CCPM:** Default to vertical slices. Allow a single "foundation" PRD (PRD-000) for shared infrastructure, then build vertical slices on top.

Sources: [Bogard - Vertical Slice Architecture](https://www.jimmybogard.com/vertical-slice-architecture/), [Visual Paradigm - Vertical vs Horizontal](https://www.visual-paradigm.com/scrum/user-story-splitting-vertical-slice-vs-horizontal-slice/), [Scrum.org Forum Discussion](https://www.scrum.org/forum/scrum-forum/26147/horizontal-vs-vertical-story-slicing-or-why-horizontal-slicing-considered)

### 1.2 SPIDR Framework (Evidence Grade: A)

Mike Cohn's SPIDR provides five systematic splitting techniques. For automated decomposition, apply in reverse order (R-D-I-P-S) to maximize automation potential:

| Technique | When to Apply | Automatable? | Detection Heuristic |
|-----------|--------------|-------------|---------------------|
| **R**ules | Complex business rules can be deferred | HIGH | Detect conditional logic, if/when/unless clauses |
| **D**ata | Meaningful data variations exist | HIGH | Detect entity types, data format mentions |
| **I**nterface | Different interfaces need different implementations | MEDIUM | Detect platform/device/channel mentions |
| **P**aths | Multiple user workflows through a feature | MEDIUM | Detect OR conditions, alternative flows |
| **S**pikes | Technical uncertainty requires research | LOW | Detect uncertainty language, "investigate", "evaluate" |

**Strategy selection algorithm:**

```python
def select_decomposition_strategy(item: RoadmapItem) -> Strategy:
    """Select the best decomposition strategy based on item characteristics."""
    # Check for uncertainty first (spike needed)
    if has_high_uncertainty(item):
        return Strategy.SPIKE_FIRST

    # Story mapping for epic-sized items
    if item.estimated_size in ('XL', 'XXL') or item.child_count > 10:
        return Strategy.STORY_MAPPING

    # SPIDR techniques in order of automation feasibility
    if has_deferrable_business_rules(item):
        return Strategy.SPIDR_RULES
    elif has_data_variations(item):
        return Strategy.SPIDR_DATA
    elif has_interface_variations(item):
        return Strategy.SPIDR_INTERFACE
    elif has_alternative_paths(item):
        return Strategy.SPIDR_PATHS

    # Default: vertical slice by user journey
    return Strategy.VERTICAL_SLICE
```

Sources: [Cohn - SPIDR](https://www.mountaingoatsoftware.com/blog/five-simple-but-powerful-ways-to-split-user-stories), [Humanizing Work - Guide to Splitting](https://www.humanizingwork.com/the-humanizing-work-guide-to-splitting-user-stories/)

### 1.3 User Story Mapping (Evidence Grade: A)

Jeff Patton's story mapping provides a complementary approach for epic-sized items:

**Structure:**
- Top level: Activities (narrative backbone -- what users do)
- Under activities: User tasks and stories
- Horizontal line: Separates MVP from later releases

**Six-step process:**
1. Frame the problem (who, why)
2. Map the big picture (breadth over depth)
3. Explore (other users, edge cases, failures)
4. Slice out a release strategy
5. Slice out a learning strategy (MVPs for risks)
6. Slice out a development strategy

**Key insight for automation:** "The idea is NOT to gather a set of written requirements, but rather help teams build consensus, a common understanding of user problems." This means automated decomposition should produce a draft that humans refine -- not a final answer.

Source: [Patton - Story Mapping](https://jpattonassociates.com/story-mapping/)

### 1.4 Humanizing Work Splitting Patterns (Evidence Grade: A)

The Humanizing Work guide identifies 9 concrete splitting patterns, each with automation potential:

| Pattern | Description | Automation Potential |
|---------|-------------|---------------------|
| Workflow Steps | Simple end-to-end first, then special cases | HIGH - detect sequential steps |
| Operations (CRUD) | Separate create/read/update/delete | HIGH - detect entity operations |
| Business Rule Variations | Reduce variations to one | HIGH - detect conditional rules |
| Data Variations | Handle data types progressively | HIGH - detect data type mentions |
| Data Entry Methods | Split interface from core | MEDIUM - detect UI mentions |
| Major Effort | Implement one variant, then others | MEDIUM - detect enumerated items |
| Simple/Complex | Simplest version first | MEDIUM - detect complexity indicators |
| Defer Performance | "Make it work" before "make it fast" | HIGH - detect NFR keywords |
| Spike | Timeboxed investigation | LOW - detect uncertainty language |

**Meta-pattern:** "Identify core complexity, list all variations, then reduce all variations to one through a single complete slice."

**Evaluation rules for split quality:**
1. Does the split reveal deprioritizable low-value functionality?
2. Does the split produce more equally-sized stories?

Sources: [Humanizing Work Guide](https://www.humanizingwork.com/the-humanizing-work-guide-to-splitting-user-stories/), [Humanizing Work Anti-Patterns](https://www.humanizingwork.com/10-anti-patterns-for-user-story-splitting-a-k-a-how-not-to-split-user-stories/)

### 1.5 SAFe Decomposition Hierarchy (Evidence Grade: A)

For enterprise-scale roadmaps, SAFe provides a clear decomposition hierarchy:

```
Portfolio Level:  EPIC (strategic initiative, spans multiple PIs)
                    |
Large Solution:   CAPABILITY (multi-ART functionality)
                    |
Program Level:    FEATURE (deliverable in a single PI)
                    |
Team Level:       STORY (completable in a single sprint)
```

**Mapping to CCPM:**
- Roadmap item --> Epic
- PRD --> Feature (deliverable capability, sized for one PI/milestone)
- Implementation task --> Story (sized for one sprint/agent session)

**Decomposition timing:** "Break down epics one to two sprints before you need to start work. Earlier decomposition often becomes outdated; later decomposition causes planning delays."

Sources: [SAFe - Epic](https://framework.scaledagile.com/epic), [SAFe - Story](https://framework.scaledagile.com/story), [Tempo - SAFe Hierarchy](https://www.tempo.io/blog/which-safe-hierarchy-should-you-choose)

---

## 2. Dependency Graph Construction

### 2.1 Dependency Type Taxonomy (Evidence Grade: B)

Research identifies seven fine-grained dependency types between requirements (LEREDD taxonomy, validated on 813 requirement pairs):

| Type | Definition | Edge Direction | Cycle Risk |
|------|-----------|---------------|-----------|
| **Requires** | Fulfillment of one is prerequisite for the other | Prerequisite --> Dependent | Medium |
| **Implements** | Higher-level requirement fulfilled by lower-level | Parent --> Child | Low |
| **Conflicts** | Fulfillment of one restricts the other | Bidirectional flag | High |
| **Contradicts** | Mutually exclusive requirements | Bidirectional flag | High |
| **Details** | Same action, one adds specifics | General --> Specific | Low |
| **Is Similar** | Requirements replicate content | Metadata link | None |
| **Is a Variant** | One serves as alternative to the other | Metadata link | Low |

**For DAG construction, only "Requires" and "Implements" create directed edges.** Conflicts/Contradicts are validation errors to resolve. Details/Similar/Variant are metadata links, not ordering constraints.

**Simplified taxonomy for CCPM:**

| Edge Type | Semantics | Creates Ordering Constraint? |
|-----------|-----------|------------------------------|
| `blocks` | Must complete A before starting B | YES |
| `informs` | A provides context useful for B | NO (soft link) |
| `conflicts` | A and B have incompatible requirements | VALIDATION ERROR |
| `related` | A and B touch similar concerns | NO (metadata) |

Sources: [LEREDD (arXiv:2602.22456)](https://arxiv.org/abs/2602.22456), [van Lamsweerde & Letier - Feature-driven dependency analysis](https://link.springer.com/article/10.1007/s00766-006-0033-x)

### 2.2 Dependency Detection Methods

#### 2.2.1 Explicit Dependency Extraction

Parse PRD text for explicit dependency markers:

```python
DEPENDENCY_PATTERNS = [
    # Direct statements
    (r'depends on\s+(?:PRD[- ]?\w+)', 'blocks'),
    (r'requires\s+(?:PRD[- ]?\w+)', 'blocks'),
    (r'blocked by\s+(?:PRD[- ]?\w+)', 'blocks'),
    (r'after\s+(?:PRD[- ]?\w+)\s+(?:is |has been )?(?:complete|done|finished)', 'blocks'),
    (r'builds on\s+(?:PRD[- ]?\w+)', 'blocks'),

    # Soft dependencies
    (r'informed by\s+(?:PRD[- ]?\w+)', 'informs'),
    (r'related to\s+(?:PRD[- ]?\w+)', 'related'),
    (r'see also\s+(?:PRD[- ]?\w+)', 'related'),
]
```

#### 2.2.2 Implicit Dependency Detection

Implicit dependencies are harder -- they require semantic analysis. Three approaches, in order of sophistication:

**Approach 1: Entity Overlap Analysis (simple, fast)**
```python
def detect_entity_overlap(prd_a: PRD, prd_b: PRD) -> float:
    """Detect shared data entities between PRDs.
    High overlap suggests implicit dependency."""
    entities_a = extract_entities(prd_a)  # nouns, data models, API endpoints
    entities_b = extract_entities(prd_b)
    overlap = entities_a & entities_b
    return len(overlap) / max(len(entities_a | entities_b), 1)
```

**Approach 2: Semantic Similarity with Embedding (moderate)**
Using sentence embeddings (SBERT, Universal Sentence Encoder) to find semantically related PRDs, then checking for ordering constraints:

```python
def detect_semantic_dependency(prd_a: PRD, prd_b: PRD, threshold=0.7) -> bool:
    """High semantic similarity + ordering keywords = likely dependency."""
    similarity = cosine_similarity(embed(prd_a.text), embed(prd_b.text))
    if similarity > threshold:
        return has_ordering_relationship(prd_a, prd_b)
    return False
```

**Approach 3: LLM-Based Detection with RAG (LEREDD approach, highest accuracy)**

The LEREDD system (Feb 2026) achieves the best results by combining RAG for domain context with ICL for dynamic example retrieval:

| Method | Accuracy | F1 (Requires) | F1 (No Dependency) |
|--------|----------|---------------|-------------------|
| Zero-shot LLM | ~0.80 | ~0.35 | ~0.89 |
| Fine-tuned BERT | 0.63 | 0.52 | 0.70 |
| TF-IDF & LSA | 0.73 | 0.28 | 0.87 |
| **LEREDD (RAG + ICL)** | **0.93** | **0.73** | **0.96** |

**Key insight from LEREDD:** "Dependency detection is not merely semantic-similarity matching but a structured form of reasoning that requires domain context." This means simple embedding similarity is insufficient -- you need domain-aware reasoning.

**Recommendation for CCPM:** Use a tiered approach:
1. **Always:** Extract explicit dependencies from PRD text (regex patterns)
2. **Default:** Entity overlap analysis for implicit dependencies (fast, no API cost)
3. **When available:** LLM-based detection with RAG for high-confidence dependency classification (uses API tokens but significantly more accurate)

Sources: [LEREDD (arXiv:2602.22456)](https://arxiv.org/html/2602.22456), [NLP for RE Systematic Mapping](https://dl.acm.org/doi/10.1145/3444689), [Automated Requirements Relations Extraction](https://arxiv.org/html/2401.12075v2)

### 2.3 DAG Construction and Validation

#### 2.3.1 Core Data Structure

```python
class DependencyDAG:
    def __init__(self):
        self.nodes: Dict[str, PRDNode] = {}
        self.edges: List[Edge] = []
        self.adjacency: Dict[str, List[str]] = {}  # from_id -> [to_id]
        self.reverse_adj: Dict[str, List[str]] = {}  # to_id -> [from_id]

    def add_prd(self, prd_id: str, metadata: dict) -> None:
        self.nodes[prd_id] = PRDNode(prd_id, metadata)
        self.adjacency.setdefault(prd_id, [])
        self.reverse_adj.setdefault(prd_id, [])

    def add_dependency(self, from_id: str, to_id: str,
                       dep_type: str = 'blocks',
                       confidence: float = 1.0) -> tuple[bool, str]:
        """Add dependency edge. Returns (success, error_message)."""
        if dep_type not in ('blocks', 'informs', 'related', 'conflicts'):
            return False, f"Unknown dependency type: {dep_type}"

        if dep_type != 'blocks':
            # Non-blocking deps don't create ordering constraints
            self.edges.append(Edge(from_id, to_id, dep_type, confidence))
            return True, None

        # Check for cycle before adding blocking edge
        if self._would_create_cycle(from_id, to_id):
            cycle_path = self._find_cycle_path(to_id, from_id)
            return False, f"Cycle: {' -> '.join(cycle_path + [from_id])}"

        self.adjacency[from_id].append(to_id)
        self.reverse_adj[to_id].append(from_id)
        self.edges.append(Edge(from_id, to_id, dep_type, confidence))
        return True, None
```

#### 2.3.2 Topological Sort (Kahn's Algorithm)

```python
def topological_sort(dag: DependencyDAG) -> list[str]:
    """Kahn's algorithm: O(V + E). Returns PRDs in valid execution order."""
    in_degree = {v: 0 for v in dag.nodes}
    for u in dag.adjacency:
        for v in dag.adjacency[u]:
            in_degree[v] += 1

    queue = deque([v for v in in_degree if in_degree[v] == 0])
    result = []

    while queue:
        u = queue.popleft()
        result.append(u)
        for v in dag.adjacency.get(u, []):
            in_degree[v] -= 1
            if in_degree[v] == 0:
                queue.append(v)

    if len(result) != len(dag.nodes):
        raise CycleDetectedError(
            f"Cycle exists: only {len(result)}/{len(dag.nodes)} nodes ordered"
        )
    return result
```

#### 2.3.3 Parallel Group Identification

```python
def get_parallel_groups(dag: DependencyDAG) -> list[list[str]]:
    """Identify groups of PRDs that can execute in parallel.

    PRDs at the same depth (longest path from any root) can run concurrently.
    This is equivalent to level assignment in the Coffman-Graham sense.
    """
    depths = {}

    # Calculate longest path to each node (critical path length)
    topo_order = topological_sort(dag)
    for node in topo_order:
        predecessors = dag.reverse_adj.get(node, [])
        if not predecessors:
            depths[node] = 0
        else:
            depths[node] = max(depths[p] + 1 for p in predecessors)

    # Group by depth
    groups = {}
    for node, depth in depths.items():
        groups.setdefault(depth, []).append(node)

    return [groups[d] for d in sorted(groups.keys())]


def get_critical_path(dag: DependencyDAG) -> list[str]:
    """Find the longest dependency chain (determines minimum total time).

    Critical path = longest path through the DAG.
    Reducing this is the only way to reduce overall schedule.
    """
    topo_order = topological_sort(dag)
    dist = {node: 0 for node in topo_order}
    predecessor = {node: None for node in topo_order}

    for u in topo_order:
        for v in dag.adjacency.get(u, []):
            if dist[u] + 1 > dist[v]:
                dist[v] = dist[u] + 1
                predecessor[v] = u

    # Trace back from the node with maximum distance
    end_node = max(dist, key=dist.get)
    path = []
    current = end_node
    while current is not None:
        path.append(current)
        current = predecessor[current]
    return list(reversed(path))
```

Sources: [Wikipedia - Topological Sorting](https://en.wikipedia.org/wiki/Topological_sorting), [Coffman-Graham Algorithm](https://en.wikipedia.org/wiki/Coffman%E2%80%93Graham_algorithm), [MIT OCW - DAGs & Scheduling](https://ocw.mit.edu/courses/6-042j-mathematics-for-computer-science-spring-2015/mit6_042js15_session17.pdf)

#### 2.3.4 Cycle Detection and Resolution

```python
def find_cycles(dag: DependencyDAG) -> list[list[str]]:
    """Tarjan's SCC algorithm: O(V + E). Returns cycles if any."""
    index_counter = [0]
    stack = []
    lowlinks = {}
    index = {}
    on_stack = set()
    sccs = []

    def strongconnect(v):
        index[v] = lowlinks[v] = index_counter[0]
        index_counter[0] += 1
        stack.append(v)
        on_stack.add(v)

        for w in dag.adjacency.get(v, []):
            if w not in index:
                strongconnect(w)
                lowlinks[v] = min(lowlinks[v], lowlinks[w])
            elif w in on_stack:
                lowlinks[v] = min(lowlinks[v], index[w])

        if lowlinks[v] == index[v]:
            scc = []
            while True:
                w = stack.pop()
                on_stack.discard(w)
                scc.append(w)
                if w == v:
                    break
            if len(scc) > 1:
                sccs.append(scc)

    for v in dag.nodes:
        if v not in index:
            strongconnect(v)

    return sccs


def resolve_cycles(dag: DependencyDAG) -> list[str]:
    """Attempt automatic cycle resolution.

    Strategy: Remove the lowest-confidence implicit edge in each cycle.
    If all edges are explicit (confidence=1.0), flag for human review.
    """
    cycles = find_cycles(dag)
    removed_edges = []

    for cycle in cycles:
        # Find the weakest edge in the cycle
        cycle_edges = []
        for i in range(len(cycle)):
            from_id = cycle[i]
            to_id = cycle[(i + 1) % len(cycle)]
            edge = dag.get_edge(from_id, to_id)
            if edge:
                cycle_edges.append(edge)

        # Sort by confidence (remove least confident first)
        cycle_edges.sort(key=lambda e: e.confidence)

        if cycle_edges and cycle_edges[0].confidence < 1.0:
            weakest = cycle_edges[0]
            dag.remove_edge(weakest.from_id, weakest.to_id)
            removed_edges.append(weakest)
        else:
            raise CycleUnresolvableError(
                f"All edges in cycle are explicit: {' -> '.join(cycle)}. "
                "Manual intervention required."
            )

    return removed_edges
```

**Cycle resolution strategies (in order of preference):**

| Strategy | When | How |
|----------|------|-----|
| Remove implicit edge | Lowest-confidence edge in cycle | Automatic |
| Extract shared component | Two PRDs share bidirectional dependency | Create a third PRD for shared part |
| Merge PRDs | Tight mutual dependency | Combine into one PRD |
| Dependency inversion | A depends on B and B on A | Introduce abstraction/interface PRD |
| Human intervention | All edges explicit, high confidence | Flag for review |

Sources: [Wikipedia - Tarjan's SCC](https://en.wikipedia.org/wiki/Tarjan%27s_strongly_connected_components_algorithm), [AlgoCademy - Circular Dependencies Guide](https://algocademy.com/blog/how-to-handle-circular-dependencies-a-comprehensive-guide/)

---

## 3. Independence Boundaries

### 3.1 What Makes a Good PRD Boundary

A good PRD boundary produces a unit that is independently implementable, testable, and valuable. Evidence from multiple sources converges on these characteristics:

**From DDD/Microservices (Microsoft Architecture Center):**
- Maps to a bounded context or aggregate
- Has high internal cohesion (elements work together for one purpose)
- Has low external coupling (minimal dependencies on other PRDs)
- Can be deployed/delivered independently
- Has a single, clear responsibility

**From INVEST (Agile Alliance):**
- **Independent:** Can be implemented without waiting for other PRDs
- **Negotiable:** Implementation details are flexible
- **Valuable:** Delivers demonstrable user value
- **Estimable:** Clear enough to size
- **Small:** Completable in a reasonable timeframe (1-2 sprints for a team, 1 agent session for AI)
- **Testable:** Has clear acceptance criteria

**From DDD Boundary Identification (Azure Architecture Center):**

The process for deriving service boundaries from a domain model:
1. Start with a bounded context (functionality in a PRD should not span multiple contexts)
2. Look at aggregates (a well-designed aggregate has high cohesion and loose coupling)
3. Consider domain services (stateless operations across aggregates)
4. Validate: single responsibility, no chatty calls, independently deployable, not tightly coupled

**Validation criteria for PRD boundaries:**

```python
def validate_prd_boundary(prd: PRD, all_prds: list[PRD]) -> BoundaryScore:
    """Score a PRD boundary on 0.0-1.0 scale."""
    scores = {}

    # Cohesion: do all acceptance criteria relate to one capability?
    scores['cohesion'] = calculate_internal_cohesion(prd)

    # Coupling: how many other PRDs does this PRD reference?
    dep_count = len(prd.dependencies)
    total_prds = len(all_prds)
    scores['coupling'] = 1.0 - min(1.0, dep_count / max(total_prds * 0.3, 1))

    # Value: does it deliver independently testable user value?
    scores['value'] = calculate_value_score(prd)

    # Size: is it appropriately sized? (not too big, not too small)
    scores['size'] = calculate_size_score(prd)

    # Completeness: does it cover its bounded context fully?
    scores['completeness'] = calculate_completeness(prd)

    composite = (
        scores['cohesion'] * 0.25 +
        scores['coupling'] * 0.25 +
        scores['value'] * 0.20 +
        scores['size'] * 0.15 +
        scores['completeness'] * 0.15
    )

    return BoundaryScore(scores=scores, composite=composite)
```

Sources: [Microsoft - Microservice Boundaries](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/microservice-boundaries), [Agile Alliance - INVEST](https://agilealliance.org/glossary/invest/), [Fowler - Bounded Context](https://martinfowler.com/bliki/BoundedContext.html)

### 3.2 Coupling and Cohesion Metrics

**Coupling** (between PRDs): The degree of interdependence between PRDs. Measured by:
- Number of shared entities/data models
- Number of shared API endpoints
- Frequency of cross-references in text
- Dependency edge count in the DAG

**Cohesion** (within a PRD): The degree to which elements within a PRD work together for a single purpose. Measured by:
- Semantic similarity of acceptance criteria (should be high)
- Entity diversity (should be low -- few distinct data models)
- Layer coverage (vertical slice should touch all layers for ONE feature)

**Information-theory approach (Allen & Khoshgoftaar, 2001):** Coupling and cohesion can be measured using information entropy -- a module with high cohesion has low internal entropy (elements are predictably related), while a system with low coupling has low inter-module entropy.

For PRD decomposition, the practical heuristic is:

```
Maximize: sum(cohesion(prd) for prd in prds)
Minimize: sum(coupling(prd_i, prd_j) for all pairs (i, j))
```

This is equivalent to a graph partitioning problem where we want to maximize intra-partition edge density and minimize inter-partition edges.

Sources: [IEEE - Measuring Coupling and Cohesion](https://ieeexplore.ieee.org/document/915521/), [GeeksforGeeks - Coupling and Cohesion](https://www.geeksforgeeks.org/software-engineering/software-engineering-coupling-and-cohesion/)

---

## 4. Automated Decomposition in Practice

### 4.1 LLM-Based Decomposition

#### Industry Reality (Evidence Grade: A)

| Metric | Value | Source |
|--------|-------|--------|
| Industry AI adoption in RE | 58.2% | arXiv:2511.01324 |
| Positive perception | 69.1% | arXiv:2511.01324 |
| Full automation | 5.4% | arXiv:2511.01324 |
| Human-AI collaboration | 54.4% | arXiv:2511.01324 |
| Believe LLM can do analysis alone | 0% | arXiv:2511.01324 |

**Critical finding:** "Full AI autonomy was mostly rejected, with only 2% believing that AI could handle elicitation independently without human intervention, while no one believed that AI could handle analysis, specification, and validation independently without human intervention."

#### LLM Capabilities in Decomposition

| Capability | LLM Performance | Notes |
|-----------|----------------|-------|
| Initial draft generation | GOOD | Produces reasonable first-pass decomposition |
| Pattern recognition | GOOD | Identifies common requirement types, CRUD patterns |
| Explicit dependency extraction | GOOD | Detects stated dependencies in text |
| Implicit dependency detection | POOR (zero-shot) | Needs RAG + ICL to reach 0.73 F1 |
| Business value assessment | POOR | Cannot judge stakeholder priorities |
| Trade-off resolution | POOR | Requires human judgment |
| Anti-pattern detection | MEDIUM | Can flag obvious issues, misses subtle ones |
| Format consistency | GOOD | Reliably produces structured output |

#### Prompting Strategy

**Recommended: Few-shot + Template + Reasoning (structured chain-of-thought)**

Research shows that LLM-based prompted decomposition works best when combining:
1. Schema-guided prompts with domain-specific structures
2. Few-shot demonstrations showing ideal decompositions (3-5 examples, saturation at ~5)
3. Hierarchical/recursive designs enabling sub-decomposition
4. Explicit output format constraints

```python
def build_decomposition_prompt(roadmap_item: dict, context: dict) -> str:
    return f"""You are an expert product manager decomposing a roadmap item
into independent PRDs.

<context>
Roadmap Item: {roadmap_item['title']}
Description: {roadmap_item['description']}
Goals: {roadmap_item.get('goals', 'Not specified')}
Constraints: {roadmap_item.get('constraints', 'None')}
Existing PRDs: {context.get('existing_prds', [])}
</context>

<rules>
1. Each PRD must deliver STANDALONE USER VALUE (vertical slice)
2. Each PRD must be independently implementable and testable
3. Target 3-7 PRDs per roadmap item
4. Size each PRD for completion in 1-2 sprints or 1 AI agent session
5. Declare explicit dependencies between PRDs using "blocks" relationships
6. Apply SPIDR techniques: Rules > Data > Interface > Paths > Spikes
</rules>

<anti_patterns>
Avoid these decomposition failures:
- Splitting by technical layer (DB, API, UI as separate PRDs)
- Splitting by process step without standalone value
- Separating happy path from error handling
- Creating "foundation/core" PRDs with no end-to-end value
- CRUD splits of the same entity (create/read/update/delete as 4 PRDs)
</anti_patterns>

<examples>
{format_few_shot_examples(context.get('examples', []))}
</examples>

<output_format>
Return valid JSON:
{{
  "prds": [{{
    "id": "PRD-001",
    "title": "Short descriptive title",
    "user_story": "As a [role], I want [goal], so that [benefit]",
    "acceptance_criteria": ["Given/When/Then format preferred"],
    "dependencies": [{{"prd_id": "PRD-000", "type": "blocks"}}],
    "size": "S|M|L",
    "rationale": "Why this is a good vertical slice"
  }}],
  "dependency_rationale": "Explanation of dependency relationships",
  "decomposition_strategy": "Which SPIDR technique was primary"
}}
</output_format>"""
```

Sources: [arXiv:2509.11446 - LLMs for RE: SLR](https://arxiv.org/html/2509.11446v1), [arXiv:2511.01324 - AI for RE: Industry](https://arxiv.org/html/2511.01324v2), [EmergentMind - LLM Prompted Decomposition](https://www.emergentmind.com/topics/llm-based-prompted-decomposition)

### 4.2 AI Agent Task Decomposition (Evidence Grade: B)

Modern AI coding agents provide empirical evidence for automated task decomposition:

**GitHub Copilot Workspace (sunset May 2025):** Demonstrated the pattern of: natural language input --> specification --> step-by-step plan --> code changes. Key learning: "When you can steer the system at each step, you supply crucial information that helps the model generate code, and the resulting code is more likely to be correct."

**Claude Code, Cursor, Devin:** Modern agents (2025-2026) follow a consistent pattern:
1. Read and understand the repository context
2. Create a plan (decompose the task)
3. Execute steps sequentially
4. Verify results
5. Iterate on failures

**Key insight:** All successful agent architectures use human-in-the-loop at the planning stage, not just execution. This validates the human review gate in the CCPM architecture.

**Task decomposition in agent frameworks:**
- **TaskWeaver:** Modular task decomposition prioritizing testable steps
- **AutoGen:** Multi-agent conversation for collaborative decomposition
- **crewAI:** Role-based agents collaborating on structured tasks

Sources: [GitHub Next - Copilot Workspace](https://githubnext.com/projects/copilot-workspace), [IBM - AI Agent Planning](https://www.ibm.com/think/topics/ai-agent-planning), [Faros AI - Best AI Coding Agents 2026](https://www.faros.ai/blog/best-ai-coding-agents-2026)

### 4.3 Hallucination Detection and Mitigation

LLM decomposition outputs can contain fabricated dependencies, invented requirements, or inconsistent PRDs. Three detection methods:

**1. Self-Consistency Check:**
Generate N decompositions (N=3) with temperature variation. Flag any PRD or dependency that appears in fewer than 2/3 of outputs.

**2. Metamorphic Testing:**
Rephrase the roadmap item without changing meaning. If the decomposition changes substantially, the original may be hallucinated.

**3. Structural Validation:**
Verify the decomposition against known constraints:
- Do all PRDs reference entities mentioned in the roadmap item?
- Are dependency relationships logically consistent?
- Does the union of PRD scopes cover the roadmap item scope?

Sources: [arXiv:2510.25016 - Human-AI Synergy in RE](https://www.arxiv.org/pdf/2510.25016)

---

## 5. Topological Ordering and Scheduling

### 5.1 Execution Order

Once the DAG is validated, topological sort produces a valid execution order. The algorithm guarantees: for every dependency edge (A, B), PRD A appears before PRD B in the order.

**Key properties:**
- Multiple valid orderings may exist (the sort is not unique)
- All valid orderings respect dependency constraints
- The choice between valid orderings can optimize for parallelism

### 5.2 Parallelism Opportunities

The parallel group identification algorithm (Section 2.3.3) produces "waves" of PRDs that can execute simultaneously:

```
Wave 0: [PRD-001, PRD-002]          # No dependencies, start immediately
Wave 1: [PRD-003, PRD-004, PRD-005] # Depend only on Wave 0 PRDs
Wave 2: [PRD-006]                   # Depends on Wave 1 PRDs
Wave 3: [PRD-007]                   # Depends on Wave 2 PRDs
```

**Parallelism factor** = average wave size = total PRDs / number of waves

A high parallelism factor means most PRDs can be worked on concurrently. A low factor (close to 1.0) means the dependency chain is deep and serialization is unavoidable.

### 5.3 Critical Path Analysis

The critical path is the longest chain of dependent PRDs. It determines the minimum possible completion time regardless of how many agents/teams are available.

```
Critical path length = max depth of DAG
Minimum completion time = sum(estimated_duration(prd) for prd in critical_path)
```

**Practical implications:**
- Shortening the critical path is the only way to reduce total schedule
- PRDs on the critical path should be prioritized and resourced first
- PRDs NOT on the critical path have "float" -- they can be delayed without affecting total schedule

### 5.4 Scheduling Algorithm

For CCPM, a modified Coffman-Graham approach:

```python
def schedule_prds(dag: DependencyDAG, max_parallel: int = 3) -> Schedule:
    """Schedule PRDs respecting dependencies and parallelism limits.

    Uses modified Coffman-Graham: assign levels, then schedule within
    parallelism bound W.

    For W=2, this is optimal. For W>2, it's within factor 2-2/W of optimal.
    """
    groups = get_parallel_groups(dag)
    schedule = Schedule()

    for wave_idx, group in enumerate(groups):
        # Within each wave, prioritize by:
        # 1. Number of downstream dependents (more dependents = do first)
        # 2. Estimated size (larger = start sooner)
        group.sort(key=lambda prd_id: (
            -count_downstream(dag, prd_id),
            -dag.nodes[prd_id].estimated_size
        ))

        # Assign to parallel slots
        for i, prd_id in enumerate(group):
            slot = i % max_parallel
            schedule.assign(prd_id, wave=wave_idx, slot=slot)

    return schedule
```

Sources: [Coffman-Graham Algorithm](https://en.wikipedia.org/wiki/Coffman%E2%80%93Graham_algorithm), [MIT OCW - DAGs & Scheduling](https://ocw.mit.edu/courses/6-042j-mathematics-for-computer-science-spring-2015/mit6_042js15_session17.pdf)

---

## 6. Validation and Quality

### 6.1 MECE Validation (100% Rule)

The WBS 100% rule requires that decomposition is Mutually Exclusive and Collectively Exhaustive:

**Collectively Exhaustive (no gaps):** The union of all PRD scopes must cover 100% of the roadmap item scope.

```python
def check_completeness(roadmap_item: dict, prds: list[PRD]) -> CompletenessResult:
    """Check that PRDs collectively cover the roadmap item scope."""
    # Extract key concepts from roadmap item
    roadmap_concepts = extract_key_concepts(roadmap_item['description'])
    roadmap_goals = extract_goals(roadmap_item)
    roadmap_personas = extract_personas(roadmap_item)

    # Extract concepts covered by PRDs
    prd_concepts = set()
    prd_goals = set()
    prd_personas = set()
    for prd in prds:
        prd_concepts |= extract_key_concepts(prd.full_text)
        prd_goals |= extract_goals_from_prd(prd)
        prd_personas |= extract_personas_from_prd(prd)

    # Calculate coverage
    concept_coverage = len(roadmap_concepts & prd_concepts) / max(len(roadmap_concepts), 1)
    goal_coverage = len(roadmap_goals & prd_goals) / max(len(roadmap_goals), 1)
    persona_coverage = len(roadmap_personas & prd_personas) / max(len(roadmap_personas), 1)

    uncovered = roadmap_concepts - prd_concepts
    return CompletenessResult(
        concept_coverage=concept_coverage,
        goal_coverage=goal_coverage,
        persona_coverage=persona_coverage,
        uncovered_concepts=uncovered,
        is_complete=concept_coverage > 0.9 and goal_coverage > 0.9
    )
```

**Mutually Exclusive (no overlaps):** Each PRD should have a distinct scope. Overlap indicates either:
- Redundant work (waste)
- Unclear boundaries (integration risk)
- Missing shared component (should be extracted)

```python
def check_overlap(prds: list[PRD]) -> list[OverlapWarning]:
    """Detect scope overlap between PRD pairs."""
    warnings = []
    for i, prd_a in enumerate(prds):
        for prd_b in prds[i+1:]:
            # Check acceptance criteria overlap
            ac_overlap = calculate_criteria_overlap(prd_a, prd_b)
            # Check entity overlap
            entity_overlap = calculate_entity_overlap(prd_a, prd_b)

            if ac_overlap > 0.3 or entity_overlap > 0.5:
                warnings.append(OverlapWarning(
                    prd_a=prd_a.id, prd_b=prd_b.id,
                    ac_overlap=ac_overlap,
                    entity_overlap=entity_overlap,
                    suggestion="Consider merging or extracting shared component"
                ))
    return warnings
```

Sources: [PMI - WBS Quality](https://www.pmi.org/learning/library/creating-effective-wbs-recognize-quality-7541), [MECE Principle](https://en.wikipedia.org/wiki/MECE_principle), [Epicflow - WBS Creation](https://www.epicflow.com/blog/creating-a-work-breakdown-structure-what-you-need-to-know/)

### 6.2 INVEST Scoring

Automated INVEST scoring provides quality signals for each PRD:

```python
def calculate_invest_score(prd: PRD, all_prds: list[PRD]) -> INVESTScore:
    """Score a PRD on the INVEST criteria. Each dimension 0.0-1.0."""
    scores = {}

    # Independent: fewer dependencies = more independent
    dep_count = len([d for d in prd.dependencies if d.type == 'blocks'])
    scores['independent'] = max(0, 1.0 - dep_count * 0.2)

    # Negotiable: has implementation flexibility indicators
    scores['negotiable'] = calculate_negotiability(prd)

    # Valuable: delivers user-facing value
    scores['valuable'] = calculate_value(prd)

    # Estimable: clear enough to estimate
    scores['estimable'] = calculate_estimability(prd)

    # Small: appropriately sized
    scores['small'] = calculate_size_appropriateness(prd)

    # Testable: has clear acceptance criteria
    scores['testable'] = calculate_testability(prd)

    weights = {
        'independent': 0.25,  # Most important for decomposition
        'negotiable': 0.05,   # Least critical
        'valuable': 0.20,     # Core quality signal
        'estimable': 0.15,    # Implementation readiness
        'small': 0.15,        # Sizing quality
        'testable': 0.20,     # Verification readiness
    }

    composite = sum(scores[k] * weights[k] for k in scores)

    return INVESTScore(**scores, composite=composite)


def calculate_value(prd: PRD) -> float:
    """Score the user value of a PRD."""
    score = 0.0
    # Has user story with role, goal, and benefit
    if re.search(r'[Aa]s a[n]?\s+\w+', prd.user_story):
        score += 0.3
    if 'so that' in prd.user_story.lower():
        score += 0.3
    # Contains action verbs indicating user capability
    action_verbs = ['create', 'view', 'manage', 'track', 'analyze',
                    'purchase', 'share', 'configure', 'export', 'import']
    if any(v in prd.full_text.lower() for v in action_verbs):
        score += 0.2
    # Low ratio of technical jargon (user-focused, not tech-focused)
    tech_ratio = count_tech_terms(prd) / max(word_count(prd), 1)
    if tech_ratio < 0.2:
        score += 0.2
    return min(1.0, score)


def calculate_testability(prd: PRD) -> float:
    """Score testability based on acceptance criteria quality."""
    score = 0.0
    if prd.acceptance_criteria:
        score += 0.4  # Has acceptance criteria at all
        # Check for structured format (Given/When/Then)
        structured = sum(
            1 for ac in prd.acceptance_criteria
            if re.search(r'(given|when|then|should|verify|expect)', ac.lower())
        )
        score += 0.3 * (structured / len(prd.acceptance_criteria))
    # Check for measurable criteria (numbers, percentages, timeframes)
    if re.search(r'\d+\s*(seconds?|ms|minutes?|%|items?|users?|requests?)', prd.full_text):
        score += 0.3
    return min(1.0, score)
```

Sources: [Agile Alliance - INVEST](https://agilealliance.org/glossary/invest/), [ResearchGate - INVEST Criteria](https://www.researchgate.net/publication/260741443_Improving_the_User_Story_Agile_Technique_Using_the_INVEST_Criteria)

### 6.3 Anti-Pattern Detection

10 documented anti-patterns that automated decomposition must detect and flag:

| # | Anti-Pattern | Severity | Detection Heuristic |
|---|-------------|----------|---------------------|
| 1 | **Horizontal slice** | HIGH | Single layer keywords only (all UI, all API, all DB) |
| 2 | **Process step split** | MEDIUM | Sequential markers without standalone value |
| 3 | **Happy path only** | HIGH | Missing error/edge case keywords |
| 4 | **Core first** | HIGH | "Core/base/foundation" keywords with no user value |
| 5 | **CRUD split** | MEDIUM | Same entity with different CRUD verbs as separate PRDs |
| 6 | **Trivial data split** | MEDIUM | Structurally identical PRDs differing only in data |
| 7 | **Superficial interface** | MEDIUM | Differs only by web/mobile/platform |
| 8 | **Bad conjunction split** | MEDIUM | Setup-only PRD with no user outcome |
| 9 | **Superficial role split** | MEDIUM | Same functionality, different user roles |
| 10 | **Test case as PRD** | MEDIUM | Test language dominates, no feature description |

```python
class AntiPatternDetector:
    def analyze(self, prds: list[PRD]) -> list[AntiPatternWarning]:
        warnings = []

        # Check each PRD individually
        for prd in prds:
            if self._is_horizontal_slice(prd):
                warnings.append(AntiPatternWarning(
                    pattern='horizontal_slice', severity='HIGH',
                    prd_id=prd.id,
                    message=f'{prd.id} appears to be a horizontal slice (single layer)',
                    fix='Restructure to include all layers for a single feature'
                ))
            if self._is_happy_path_only(prd):
                warnings.append(AntiPatternWarning(
                    pattern='happy_path_only', severity='HIGH',
                    prd_id=prd.id,
                    message=f'{prd.id} covers only happy path, no error handling',
                    fix='Include basic error handling in the same PRD'
                ))
            if self._is_core_first(prd):
                warnings.append(AntiPatternWarning(
                    pattern='core_first', severity='HIGH',
                    prd_id=prd.id,
                    message=f'{prd.id} is a foundation/core PRD with no user value',
                    fix='Extend to include minimal end-to-end user functionality'
                ))

        # Check PRD pairs for relationship anti-patterns
        for i, prd_a in enumerate(prds):
            for prd_b in prds[i+1:]:
                if self._is_crud_split(prd_a, prd_b):
                    warnings.append(AntiPatternWarning(
                        pattern='crud_split', severity='MEDIUM',
                        prd_id=f'{prd_a.id}+{prd_b.id}',
                        message=f'CRUD split: {prd_a.id} and {prd_b.id} split same entity by operation',
                        fix='Consider combining into one PRD or splitting by user journey instead'
                    ))

        return warnings

    def _is_horizontal_slice(self, prd: PRD) -> bool:
        layers = {
            'ui': ['frontend', 'ui', 'interface', 'view', 'component', 'page', 'form'],
            'api': ['api', 'endpoint', 'service', 'backend', 'controller', 'route'],
            'db': ['database', 'schema', 'migration', 'table', 'model', 'query'],
        }
        text = prd.full_text.lower()
        layers_mentioned = sum(
            1 for keywords in layers.values()
            if any(kw in text for kw in keywords)
        )
        return layers_mentioned == 1  # Only one layer = horizontal slice

    def _is_happy_path_only(self, prd: PRD) -> bool:
        error_keywords = ['error', 'fail', 'invalid', 'exception', 'edge case',
                         'timeout', 'retry', 'fallback', 'validation error']
        has_error_handling = any(kw in prd.full_text.lower() for kw in error_keywords)
        happy_indicators = ['happy path', 'main flow', 'basic flow', 'simple case']
        is_happy_focused = any(ind in prd.full_text.lower() for ind in happy_indicators)
        return not has_error_handling or is_happy_focused

    def _is_core_first(self, prd: PRD) -> bool:
        core_indicators = ['core', 'base', 'foundation', 'infrastructure',
                          'framework', 'platform', 'scaffold']
        has_core = any(ind in prd.full_text.lower() for ind in core_indicators)
        has_value = bool(re.search(r'[Aa]s a[n]?\s+\w+', prd.user_story or ''))
        return has_core and not has_value
```

Sources: [Humanizing Work - 10 Anti-Patterns](https://www.humanizingwork.com/10-anti-patterns-for-user-story-splitting-a-k-a-how-not-to-split-user-stories/), [Easy Agile - Story Splitting Anti-Patterns](https://www.easyagile.com/blog/how-not-to-split-a-user-story/), [Roman Pichler - User Story Anti-Patterns](https://www.romanpichler.com/blog/user-stories-10-anti-patterns-to-avoid/)

### 6.4 Confidence Calculation

```python
def calculate_confidence(
    consistency_score: float,
    prds: list[PRD],
    dag_validation: DAGValidation,
    antipatterns: list[AntiPatternWarning],
    completeness: CompletenessResult
) -> float:
    """Calculate overall decomposition confidence on 0.0-1.0 scale."""

    # Component 1: LLM self-consistency (0.2 weight)
    c_consistency = consistency_score * 0.2

    # Component 2: Average INVEST score (0.25 weight)
    avg_invest = sum(prd.invest_score.composite for prd in prds) / len(prds)
    c_invest = avg_invest * 0.25

    # Component 3: DAG validity (0.15 weight)
    c_dag = 0.15 if dag_validation.is_valid else 0.03

    # Component 4: Anti-pattern penalty (0.15 weight)
    high_count = sum(1 for w in antipatterns if w.severity == 'HIGH')
    medium_count = sum(1 for w in antipatterns if w.severity == 'MEDIUM')
    penalty = min(0.15, high_count * 0.05 + medium_count * 0.02)
    c_antipattern = 0.15 - penalty

    # Component 5: MECE completeness (0.15 weight)
    c_completeness = completeness.concept_coverage * 0.15

    # Component 6: PRD count reasonableness (0.10 weight)
    prd_count = len(prds)
    if 3 <= prd_count <= 7:
        c_count = 0.10
    elif 2 <= prd_count <= 10:
        c_count = 0.05
    else:
        c_count = 0.0

    total = c_consistency + c_invest + c_dag + c_antipattern + c_completeness + c_count
    return min(1.0, total)
```

**Confidence thresholds:**

| Confidence | Action | Rationale |
|------------|--------|-----------|
| >= 0.85 | Auto-approve | High certainty across all signals |
| 0.70 - 0.85 | Light review | Quick human check of flagged items |
| 0.50 - 0.70 | Full review | Human validates structure and dependencies |
| < 0.50 | Regenerate | Quality too low, reattempt with different strategy |

---

## 7. Real-World Patterns

### 7.1 Agile/SAFe Patterns

**Pattern 1: Epic-to-Feature decomposition**
SAFe's standard flow: Epic --> Capabilities --> Features --> Stories. For CCPM, the PRD sits at the Feature level -- a deliverable capability sized for one PI/milestone.

**Pattern 2: MVP-first slicing**
Story mapping's horizontal line: everything above the line is MVP, everything below is deferred. Automated decomposition should identify the MVP slice and prioritize those PRDs.

**Pattern 3: Walking skeleton**
Build the thinnest possible end-to-end system first, then flesh out features. This translates to: PRD-001 = minimal end-to-end flow, subsequent PRDs add depth.

**Pattern 4: Risk-first ordering**
High-risk/uncertain PRDs should be scheduled early (spike-first approach). The dependency graph should encode this as: spike PRDs have no dependencies and are scheduled in Wave 0.

### 7.2 Domain-Driven Design Patterns

**Pattern 5: Bounded context = PRD boundary**
Each bounded context maps to one or more PRDs. A PRD should not span multiple bounded contexts.

**Pattern 6: Aggregate as feature scope**
Within a bounded context, each aggregate (entity cluster with consistency boundary) maps naturally to a feature-sized PRD.

**Pattern 7: Context mapping for dependencies**
DDD context maps document relationships between bounded contexts. These translate directly to PRD dependency edges:
- Customer-Supplier relationship --> `blocks` dependency
- Conformist relationship --> `blocks` dependency
- Open Host Service --> `informs` dependency (shared API)
- Anticorruption Layer --> separate PRD for the adapter

Sources: [SAFe - Epic](https://framework.scaledagile.com/epic), [Microsoft - Domain Analysis for Microservices](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/domain-analysis), [Context Mapper](https://contextmapper.org/docs/bounded-context/)

---

## 8. PRD Template Schema

### 8.1 YAML Schema for Generated PRDs

```yaml
prd:
  id: string                      # e.g., "PRD-AUTH-001"
  title: string                   # < 80 chars, descriptive
  status: enum                    # draft | review | approved | in-progress | done
  created: datetime               # ISO 8601
  updated: datetime               # ISO 8601

  # Source traceability
  roadmap_item_id: string         # Which roadmap item this came from
  decomposition_strategy: string  # Which SPIDR technique was used
  decomposition_confidence: float # 0.0-1.0

  # User story
  user_story:
    role: string                  # "As a [role]"
    goal: string                  # "I want [goal]"
    benefit: string               # "So that [benefit]"

  description: string             # Markdown, max 500 words

  # Acceptance criteria
  acceptance_criteria:
    - criterion: string           # Given/When/Then preferred
      type: enum                  # functional | performance | security | ux
      testable: boolean

  # Dependencies
  dependencies:
    - prd_id: string
      type: enum                  # blocks | informs | related
      description: string

  # Sizing
  size:
    estimate: enum                # XS | S | M | L | XL
    confidence: enum              # high | medium | low
    estimated_effort_hours: int   # Optional

  # Quality scores (populated by validation)
  invest_score:
    independent: float
    negotiable: float
    valuable: float
    estimable: float
    small: float
    testable: float
    composite: float

  boundary_score:
    cohesion: float
    coupling: float
    value: float
    size: float
    completeness: float
    composite: float

  # Metadata
  tags: list[string]
  epic_id: string
  wave: int                       # Parallel execution wave (0-based)
  on_critical_path: boolean
  review_required: boolean
```

### 8.2 Output Structure

```
{output-dir}/
  decomposition-summary.md        # Overview of decomposition
  dependency-graph.json           # DAG in machine-readable format
  dependency-graph.mermaid        # Visual DAG for documentation
  execution-order.md              # Ordered list with parallel waves
  validation-report.md            # INVEST scores, anti-patterns, MECE check
  PRD-{SCOPE}-001.md              # First PRD
  PRD-{SCOPE}-002.md              # Second PRD
  ...
```

---

## 9. Complete Decomposition Algorithm

### 9.1 End-to-End Flow

```python
def decompose_roadmap_item(
    item_path: str,
    output_dir: str = './prds',
    max_prds: int = 7,
    min_prds: int = 3,
    confidence_threshold: float = 0.7,
    strategy: str = 'auto'
) -> DecompositionResult:
    """Main entry point for roadmap-to-PRD decomposition."""

    # Step 1: Parse input
    item = parse_roadmap_item(item_path)

    # Step 2: Select strategy
    if strategy == 'auto':
        strategy = select_decomposition_strategy(item)

    # Step 3: Generate PRD decomposition via LLM
    prompt = build_decomposition_prompt(item, strategy)
    draft = llm_generate(prompt, output_format='json')
    prds = parse_prd_output(draft)

    # Step 4: Self-consistency check
    consistency = self_consistency_check(item, n_samples=3)

    # Step 5: Extract dependencies (explicit + implicit)
    for prd in prds:
        prd.explicit_deps = extract_explicit_dependencies(prd)
    implicit_deps = detect_implicit_dependencies(prds)

    # Step 6: Build and validate DAG
    dag = DependencyDAG()
    for prd in prds:
        dag.add_prd(prd.id, prd.metadata)
    for prd in prds:
        for dep in prd.explicit_deps:
            success, error = dag.add_dependency(dep.from_id, prd.id, dep.type)
            if not success:
                dag.warnings.append(error)
    for dep in implicit_deps:
        if dep.confidence > 0.7:
            dag.add_dependency(dep.from_id, dep.to_id, 'blocks', dep.confidence)

    # Step 7: Detect and resolve cycles
    cycles = find_cycles(dag)
    if cycles:
        removed = resolve_cycles(dag)
        # Log removed edges for human review

    # Step 8: Calculate execution order and parallel groups
    execution_order = topological_sort(dag)
    parallel_groups = get_parallel_groups(dag)
    critical_path = get_critical_path(dag)

    # Step 9: Score each PRD
    for prd in prds:
        prd.invest_score = calculate_invest_score(prd, prds)
        prd.boundary_score = validate_prd_boundary(prd, prds)
        prd.wave = get_wave(dag, prd.id, parallel_groups)
        prd.on_critical_path = prd.id in critical_path

    # Step 10: Anti-pattern detection
    antipatterns = AntiPatternDetector().analyze(prds)

    # Step 11: MECE validation
    completeness = check_completeness(item, prds)
    overlaps = check_overlap(prds)

    # Step 12: Calculate confidence
    confidence = calculate_confidence(
        consistency, prds, dag.validate(), antipatterns, completeness
    )

    # Step 13: Determine review requirement
    needs_review = (
        confidence < confidence_threshold
        or any(w.severity == 'HIGH' for w in antipatterns)
        or not completeness.is_complete
        or len(cycles) > 0
    )

    # Step 14: Write outputs
    write_prds(prds, output_dir)
    write_dag(dag, output_dir)
    write_validation_report(prds, antipatterns, completeness, overlaps, output_dir)
    write_execution_order(parallel_groups, critical_path, output_dir)
    write_summary(item, prds, dag, confidence, needs_review, output_dir)

    return DecompositionResult(
        prds=prds,
        dag=dag,
        confidence=confidence,
        needs_review=needs_review,
        warnings=antipatterns,
        execution_order=execution_order,
        parallel_groups=parallel_groups,
        critical_path=critical_path
    )
```

### 9.2 Iterative Refinement

If confidence is below threshold, the system should attempt refinement:

```python
def refine_decomposition(result: DecompositionResult, max_attempts: int = 3) -> DecompositionResult:
    """Iteratively refine decomposition based on validation feedback."""
    for attempt in range(max_attempts):
        if result.confidence >= result.threshold:
            break

        # Build refinement prompt with specific feedback
        feedback = build_feedback_prompt(
            result.warnings,
            result.completeness,
            result.overlaps
        )
        # Re-generate with feedback
        result = decompose_with_feedback(result.item, feedback)

    return result
```

---

## 10. Implementation Priority

For building this into CCPM, implement in this order:

| Priority | Component | Value | Complexity |
|----------|-----------|-------|-----------|
| 1 | PRD template schema + writer | HIGH | LOW |
| 2 | INVEST scoring heuristics | HIGH | LOW |
| 3 | Anti-pattern detector (10 patterns) | HIGH | MEDIUM |
| 4 | DAG construction + Kahn's topological sort | HIGH | LOW |
| 5 | Tarjan's cycle detection + resolution | HIGH | LOW |
| 6 | LLM decomposition prompt (few-shot + template) | HIGH | MEDIUM |
| 7 | Parallel group identification | MEDIUM | LOW |
| 8 | Critical path analysis | MEDIUM | LOW |
| 9 | MECE completeness validation | MEDIUM | MEDIUM |
| 10 | Explicit dependency extraction (regex) | MEDIUM | LOW |
| 11 | Entity overlap implicit dependency detection | MEDIUM | MEDIUM |
| 12 | Self-consistency check | LOW | MEDIUM |
| 13 | Confidence calculation + human review gate | MEDIUM | LOW |
| 14 | LLM-based dependency detection (LEREDD approach) | LOW | HIGH |

**Rationale:** Start with validation (can be used immediately on manual decompositions), then add generation (LLM decomposition), then add sophisticated detection (implicit dependencies, self-consistency).

---

## 11. Limitations and Open Questions

### Known Limitations

1. **Formal empirical evidence is limited.** Most decomposition guidance comes from practitioner experience, not controlled studies. The LEREDD paper is one of the few with rigorous quantitative evaluation.

2. **INVEST scoring is heuristic, not definitive.** The scoring functions use keyword-based heuristics that can produce false positives/negatives. They are useful signals, not ground truth.

3. **LLM dependency detection accuracy degrades on novel domains.** LEREDD was validated on automotive systems. Performance on other domains (fintech, healthcare, consumer) is unknown. Cross-dataset generalization showed only 1.61% decline, which is promising but not definitive.

4. **Confidence thresholds are informed estimates.** The 0.7 threshold for auto-approval has not been validated empirically. It should be calibrated through real-world usage.

5. **Circular dependency resolution is partial.** Automatic resolution only works for implicit (low-confidence) edges. Explicit circular dependencies require human intervention -- and they indicate a fundamental design issue, not just a decomposition error.

### Open Questions

1. **How does decomposition quality vary by domain?** Healthcare, fintech, and consumer apps may need different strategies, weightings, and anti-pattern sets.

2. **What is the optimal PRD granularity for AI agent implementation?** The "1 sprint" heuristic from human teams may not apply to AI agents that work differently.

3. **Can retrieval-augmented decomposition (using past PRDs as examples) improve quality?** The LEREDD RAG approach suggests yes, but this hasn't been tested for decomposition (only dependency detection).

4. **How should the system handle roadmap items that are themselves ambiguous?** Current approach assumes the roadmap input is well-defined. Real roadmaps often contain vague, aspirational items.

5. **What is the right balance between decomposition depth and overhead?** Over-decomposition creates coordination overhead; under-decomposition creates implementation complexity.

### What Would Change Our Conclusions

- If LLMs demonstrate reliable implicit dependency detection in zero-shot settings (currently F1 ~0.35), the tiered detection approach could be simplified
- If formal studies show horizontal slicing outperforms vertical slicing in specific contexts (e.g., microservices with mature API contracts), the default strategy should be conditional
- If AI agent capabilities improve to handle L/XL PRDs effectively, sizing constraints could be relaxed

---

## References

### Primary Sources (Grade A)

1. Bogard, J. *Vertical Slice Architecture*. https://www.jimmybogard.com/vertical-slice-architecture/
2. Cohn, M. *Five Simple but Powerful Ways to Split User Stories (SPIDR)*. Mountain Goat Software. https://www.mountaingoatsoftware.com/blog/five-simple-but-powerful-ways-to-split-user-stories
3. Agile Alliance. *INVEST*. https://agilealliance.org/glossary/invest/
4. Lawrence, R. & Green, P. *The Humanizing Work Guide to Splitting User Stories*. https://www.humanizingwork.com/the-humanizing-work-guide-to-splitting-user-stories/
5. Lawrence, R. & Green, P. *10 Anti-Patterns for User Story Splitting*. https://www.humanizingwork.com/10-anti-patterns-for-user-story-splitting-a-k-a-how-not-to-split-user-stories/
6. Heck, P. & Zaidman, A. (2025). *Large Language Models for Requirements Engineering: A Systematic Literature Review*. arXiv:2509.11446. https://arxiv.org/html/2509.11446v1
7. Research Team (2025). *AI for Requirements Engineering: Industry Adoption*. arXiv:2511.01324. https://arxiv.org/html/2511.01324v2
8. Patton, J. *User Story Mapping*. https://jpattonassociates.com/story-mapping/
9. Wikipedia. *Topological sorting*. https://en.wikipedia.org/wiki/Topological_sorting
10. Wikipedia. *Tarjan's strongly connected components algorithm*. https://en.wikipedia.org/wiki/Tarjan%27s_strongly_connected_components_algorithm
11. Wikipedia. *Coffman-Graham algorithm*. https://en.wikipedia.org/wiki/Coffman%E2%80%93Graham_algorithm

### Grade B Sources

12. Kaddoura, S. et al. (2026). *Automating the Detection of Requirement Dependencies Using Large Language Models (LEREDD)*. arXiv:2602.22456. https://arxiv.org/abs/2602.22456
13. Microsoft. *Identify Microservice Boundaries*. Azure Architecture Center. https://learn.microsoft.com/en-us/azure/architecture/microservices/model/microservice-boundaries
14. Microsoft. *Domain Analysis for Microservices*. Azure Architecture Center. https://learn.microsoft.com/en-us/azure/architecture/microservices/model/domain-analysis
15. Scaled Agile, Inc. *Epic*. SAFe. https://framework.scaledagile.com/epic
16. Scaled Agile, Inc. *Story*. SAFe. https://framework.scaledagile.com/story
17. PMI. *Creating effective WBS*. https://www.pmi.org/learning/library/creating-effective-wbs-recognize-quality-7541
18. van Lamsweerde, A. & Letier, E. *Feature-driven requirement dependency analysis*. https://link.springer.com/article/10.1007/s00766-006-0033-x
19. Bender, M.A. et al. (2009). *A New Approach to Incremental Topological Ordering*. https://www3.cs.stonybrook.edu/~bender/newpub/BenderFiGi-soda09.pdf
20. Allen, E. & Khoshgoftaar, T. (2001). *Measuring Coupling and Cohesion*. IEEE. https://ieeexplore.ieee.org/document/915521/
21. MIT OCW. *DAGs & Scheduling*. https://ocw.mit.edu/courses/6-042j-mathematics-for-computer-science-spring-2015/mit6_042js15_session17.pdf

### Grade C Sources

22. GitHub Next. *Copilot Workspace*. https://githubnext.com/projects/copilot-workspace
23. IBM. *AI Agent Planning*. https://www.ibm.com/think/topics/ai-agent-planning
24. Fowler, M. *Bounded Context*. https://martinfowler.com/bliki/BoundedContext.html
25. Context Mapper. *Bounded Context*. https://contextmapper.org/docs/bounded-context/
26. EmergentMind. *LLM-Based Prompted Decomposition*. https://www.emergentmind.com/topics/llm-based-prompted-decomposition
27. Visual Paradigm. *Vertical Slice vs Horizontal Slice*. https://www.visual-paradigm.com/scrum/user-story-splitting-vertical-slice-vs-horizontal-slice/
28. Tempo. *SAFe hierarchy*. https://www.tempo.io/blog/which-safe-hierarchy-should-you-choose
29. Faros AI. *Best AI Coding Agents 2026*. https://www.faros.ai/blog/best-ai-coding-agents-2026
30. arXiv:2510.25016. *Towards Human-AI Synergy in Requirements*. https://www.arxiv.org/pdf/2510.25016
31. AlgoCademy. *How to Handle Circular Dependencies*. https://algocademy.com/blog/how-to-handle-circular-dependencies-a-comprehensive-guide/
32. NLP for RE: Systematic Mapping Study. https://dl.acm.org/doi/10.1145/3444689
33. Automated Requirements Relations Extraction. https://arxiv.org/html/2401.12075v2

### Standards Referenced

- IEEE Std 830 - Software Requirements Specifications
- ISO/IEC/IEEE 29148 - Requirements Engineering
- MECE Principle (McKinsey)
- WBS 100% Rule (PMI Practice Standard)

---

*Generated by deep-research agent on 2026-03-01. Revision 2.0 -- updated with LEREDD findings, DDD boundary patterns, parallel scheduling algorithms, and comprehensive validation framework.*
