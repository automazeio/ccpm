#!/usr/bin/env python3
"""
CCPM Dependency Graph Generator

Generates Mermaid diagrams showing relationships between:
- Repositories
- Commands
- Skills
- Cross-repo dependencies
"""

import logging
from typing import Any, Dict, List, Set

logger = logging.getLogger(__name__)


class DependencyGraphGenerator:
    """
    Generates Mermaid dependency graphs from CCPM configurations.
    """

    def __init__(self):
        self.nodes: Set[str] = set()
        self.edges: List[tuple] = []

    def generate(self, configs: Dict[str, Any]) -> str:
        """
        Generate a Mermaid graph from CCPM configurations.

        Args:
            configs: Dictionary of repo configs from CCPMConfigAggregator

        Returns:
            Mermaid diagram string
        """
        self.nodes = set()
        self.edges = []

        # Build graph structure
        for repo_name, config in configs.items():
            if isinstance(config, dict) and "error" not in config:
                self._process_repo(repo_name, config)

        # Generate Mermaid output
        return self._render_mermaid()

    def _process_repo(self, repo_name: str, config: Dict[str, Any]):
        """Process a single repository configuration."""
        # Create safe node ID
        repo_id = self._safe_id(repo_name)
        self.nodes.add(f'{repo_id}["{repo_name}"]')

        # Process commands
        for cmd in config.get("commands", []):
            cmd_name = cmd.get("name", "unknown")
            cmd_id = self._safe_id(f"{repo_name}_{cmd_name}")

            # Add command node
            self.nodes.add(f'{cmd_id}(("{cmd_name}"))')

            # Link repo -> command
            self.edges.append((repo_id, cmd_id, "contains"))

            # Check for cross-references in triggers
            for trigger in cmd.get("triggers", []):
                if ":" in trigger:
                    # This is a skill reference like /pm:deploy
                    skill_id = self._safe_id(trigger.replace("/", "").replace(":", "_"))
                    self.nodes.add(f'{skill_id}{{"{trigger}"}}')
                    self.edges.append((cmd_id, skill_id, "uses"))

        # Process skills
        for skill in config.get("skills", []):
            skill_name = skill.get("name", "unknown")
            skill_id = self._safe_id(f"skill_{skill_name}")
            self.nodes.add(f'{skill_id}{{"{skill_name}"}}')
            self.edges.append((repo_id, skill_id, "provides"))

        # Process rules
        for rule in config.get("rules", []):
            rule_name = rule.get("name", "unknown")
            rule_id = self._safe_id(f"rule_{repo_name}_{rule_name}")
            self.nodes.add(f'{rule_id}[/"{rule_name}"/]')
            self.edges.append((repo_id, rule_id, "enforces"))

    def _safe_id(self, name: str) -> str:
        """Create a safe Mermaid node ID."""
        # Replace problematic characters
        safe = name.replace("/", "_").replace("-", "_").replace(".", "_")
        safe = safe.replace(":", "_").replace(" ", "_")
        return safe

    def _render_mermaid(self) -> str:
        """Render the graph as Mermaid markup."""
        lines = [
            "graph TD",
            "    %% CCPM Infrastructure Dependency Graph",
            "    %% Auto-generated",
            ""
        ]

        # Add subgraph styling
        lines.append("    %% Node definitions")
        for node in sorted(self.nodes):
            lines.append(f"    {node}")

        lines.append("")
        lines.append("    %% Relationships")

        # Group edges by type
        edge_types = {}
        for source, target, rel_type in self.edges:
            if rel_type not in edge_types:
                edge_types[rel_type] = []
            edge_types[rel_type].append((source, target))

        # Render edges with different styles
        edge_styles = {
            "contains": "-->",      # Solid arrow
            "uses": "-.->",         # Dashed arrow
            "provides": "==>",      # Thick arrow
            "enforces": "-->"       # Solid arrow
        }

        for rel_type, edges in edge_types.items():
            style = edge_styles.get(rel_type, "-->")
            lines.append(f"    %% {rel_type} relationships")
            for source, target in edges:
                lines.append(f"    {source} {style} {target}")

        # Add legend
        lines.extend([
            "",
            "    %% Legend",
            "    subgraph Legend",
            '        L1["Repository"]',
            '        L2(("Command"))',
            '        L3{{"Skill"}}',
            '        L4[/"Rule"/]',
            "    end"
        ])

        return "\n".join(lines)

    def generate_summary_graph(self, configs: Dict[str, Any]) -> str:
        """
        Generate a simplified summary graph showing only repos and their relationships.
        """
        lines = [
            "graph LR",
            "    %% CCPM Repository Summary",
            ""
        ]

        repos = []
        for repo_name, config in configs.items():
            if isinstance(config, dict) and "error" not in config:
                repo_id = self._safe_id(repo_name)
                cmd_count = len(config.get("commands", []))
                skill_count = len(config.get("skills", []))
                rule_count = len(config.get("rules", []))

                label = f"{repo_name}\\n({cmd_count} cmds, {skill_count} skills)"
                repos.append((repo_id, label))

        for repo_id, label in repos:
            lines.append(f'    {repo_id}["{label}"]')

        return "\n".join(lines)


def generate_stats_table(configs: Dict[str, Any]) -> str:
    """Generate a markdown statistics table."""
    rows = []

    for repo_name, config in configs.items():
        if isinstance(config, dict) and "error" not in config:
            cmd_count = len(config.get("commands", []))
            skill_count = len(config.get("skills", []))
            rule_count = len(config.get("rules", []))
            rows.append(f"| {repo_name} | {cmd_count} | {skill_count} | {rule_count} |")

    table = [
        "| Repository | Commands | Skills | Rules |",
        "|------------|----------|--------|-------|"
    ]
    table.extend(rows)

    return "\n".join(table)


# Convenience function for standalone testing
def main():
    """Test the graph generator."""
    # Sample config for testing
    sample_configs = {
        "elysenko/ccpm": {
            "commands": [
                {"name": "deploy", "triggers": ["/pm:deploy"]},
                {"name": "sync", "triggers": ["/pm:sync"]},
            ],
            "skills": [
                {"name": "pm:deploy"},
                {"name": "pm:sync"},
            ],
            "rules": [
                {"name": "datetime"},
                {"name": "github-operations"},
            ]
        },
        "user/project": {
            "commands": [
                {"name": "build", "triggers": ["/build", "/pm:deploy"]},
            ],
            "skills": [],
            "rules": [
                {"name": "testing"},
            ]
        }
    }

    generator = DependencyGraphGenerator()
    graph = generator.generate(sample_configs)
    print("Full Graph:")
    print(graph)
    print("\n" + "=" * 50 + "\n")

    summary = generator.generate_summary_graph(sample_configs)
    print("Summary Graph:")
    print(summary)
    print("\n" + "=" * 50 + "\n")

    stats = generate_stats_table(sample_configs)
    print("Statistics:")
    print(stats)


if __name__ == "__main__":
    main()
