export function isMoveObject(content: any): content is { dataType: "moveObject"; fields: Record<string, any> } {
  return content?.dataType === "moveObject" && "fields" in content;
}

export function extractMoveObjectFields(response: any): Record<string, any> | null {
  if (response.data?.content && isMoveObject(response.data.content)) {
    return response.data.content.fields;
  }
  return null;
}