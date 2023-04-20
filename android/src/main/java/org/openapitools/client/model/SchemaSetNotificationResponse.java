/*
 * Flutter Blue Plus API
 * No description provided (generated by Openapi Generator https://github.com/openapitools/openapi-generator)
 *
 * The version of the OpenAPI document: 1.0.0
 * 
 *
 * NOTE: This class is auto generated by OpenAPI Generator (https://openapi-generator.tech).
 * https://openapi-generator.tech
 * Do not edit the class manually.
 */


package org.openapitools.client.model;

import java.util.Objects;
import java.util.Arrays;
import com.google.gson.TypeAdapter;
import com.google.gson.annotations.JsonAdapter;
import com.google.gson.annotations.SerializedName;
import com.google.gson.stream.JsonReader;
import com.google.gson.stream.JsonWriter;
import java.io.IOException;
import org.openapitools.client.model.SchemaBluetoothCharacteristic;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.google.gson.TypeAdapterFactory;
import com.google.gson.reflect.TypeToken;

import java.lang.reflect.Type;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;

import org.openapitools.client.JSON;

/**
 * SchemaSetNotificationResponse
 */
@javax.annotation.Generated(value = "org.openapitools.codegen.languages.JavaClientCodegen", date = "2023-04-20T01:41:46.146266-07:00[America/Los_Angeles]")
public class SchemaSetNotificationResponse {
  public static final String SERIALIZED_NAME_REMOTE_ID = "remote_id";
  @SerializedName(SERIALIZED_NAME_REMOTE_ID)
  private String remoteId;

  public static final String SERIALIZED_NAME_CHARACTERISTIC = "characteristic";
  @SerializedName(SERIALIZED_NAME_CHARACTERISTIC)
  private SchemaBluetoothCharacteristic characteristic;

  public static final String SERIALIZED_NAME_SUCCESS = "success";
  @SerializedName(SERIALIZED_NAME_SUCCESS)
  private Boolean success;

  public SchemaSetNotificationResponse() {
  }

  public SchemaSetNotificationResponse remoteId(String remoteId) {
    
    this.remoteId = remoteId;
    return this;
  }

   /**
   * Get remoteId
   * @return remoteId
  **/
  @javax.annotation.Nonnull

  public String getRemoteId() {
    return remoteId;
  }


  public void setRemoteId(String remoteId) {
    this.remoteId = remoteId;
  }


  public SchemaSetNotificationResponse characteristic(SchemaBluetoothCharacteristic characteristic) {
    
    this.characteristic = characteristic;
    return this;
  }

   /**
   * Get characteristic
   * @return characteristic
  **/
  @javax.annotation.Nonnull

  public SchemaBluetoothCharacteristic getCharacteristic() {
    return characteristic;
  }


  public void setCharacteristic(SchemaBluetoothCharacteristic characteristic) {
    this.characteristic = characteristic;
  }


  public SchemaSetNotificationResponse success(Boolean success) {
    
    this.success = success;
    return this;
  }

   /**
   * Get success
   * @return success
  **/
  @javax.annotation.Nonnull

  public Boolean getSuccess() {
    return success;
  }


  public void setSuccess(Boolean success) {
    this.success = success;
  }



  @Override
  public boolean equals(Object o) {
    if (this == o) {
      return true;
    }
    if (o == null || getClass() != o.getClass()) {
      return false;
    }
    SchemaSetNotificationResponse schemaSetNotificationResponse = (SchemaSetNotificationResponse) o;
    return Objects.equals(this.remoteId, schemaSetNotificationResponse.remoteId) &&
        Objects.equals(this.characteristic, schemaSetNotificationResponse.characteristic) &&
        Objects.equals(this.success, schemaSetNotificationResponse.success);
  }

  @Override
  public int hashCode() {
    return Objects.hash(remoteId, characteristic, success);
  }

  @Override
  public String toString() {
    StringBuilder sb = new StringBuilder();
    sb.append("class SchemaSetNotificationResponse {\n");
    sb.append("    remoteId: ").append(toIndentedString(remoteId)).append("\n");
    sb.append("    characteristic: ").append(toIndentedString(characteristic)).append("\n");
    sb.append("    success: ").append(toIndentedString(success)).append("\n");
    sb.append("}");
    return sb.toString();
  }

  /**
   * Convert the given object to string with each line indented by 4 spaces
   * (except the first line).
   */
  private String toIndentedString(Object o) {
    if (o == null) {
      return "null";
    }
    return o.toString().replace("\n", "\n    ");
  }


  public static HashSet<String> openapiFields;
  public static HashSet<String> openapiRequiredFields;

  static {
    // a set of all properties/fields (JSON key names)
    openapiFields = new HashSet<String>();
    openapiFields.add("remote_id");
    openapiFields.add("characteristic");
    openapiFields.add("success");

    // a set of required properties/fields (JSON key names)
    openapiRequiredFields = new HashSet<String>();
    openapiRequiredFields.add("remote_id");
    openapiRequiredFields.add("characteristic");
    openapiRequiredFields.add("success");
  }

 /**
  * Validates the JSON Object and throws an exception if issues found
  *
  * @param jsonObj JSON Object
  * @throws IOException if the JSON Object is invalid with respect to SchemaSetNotificationResponse
  */
  public static void validateJsonObject(JsonObject jsonObj) throws IOException {
      if (jsonObj == null) {
        if (!SchemaSetNotificationResponse.openapiRequiredFields.isEmpty()) { // has required fields but JSON object is null
          throw new IllegalArgumentException(String.format("The required field(s) %s in SchemaSetNotificationResponse is not found in the empty JSON string", SchemaSetNotificationResponse.openapiRequiredFields.toString()));
        }
      }

      Set<Entry<String, JsonElement>> entries = jsonObj.entrySet();
      // check to see if the JSON string contains additional fields
      for (Entry<String, JsonElement> entry : entries) {
        if (!SchemaSetNotificationResponse.openapiFields.contains(entry.getKey())) {
          throw new IllegalArgumentException(String.format("The field `%s` in the JSON string is not defined in the `SchemaSetNotificationResponse` properties. JSON: %s", entry.getKey(), jsonObj.toString()));
        }
      }

      // check to make sure all required properties/fields are present in the JSON string
      for (String requiredField : SchemaSetNotificationResponse.openapiRequiredFields) {
        if (jsonObj.get(requiredField) == null) {
          throw new IllegalArgumentException(String.format("The required field `%s` is not found in the JSON string: %s", requiredField, jsonObj.toString()));
        }
      }
      if (!jsonObj.get("remote_id").isJsonPrimitive()) {
        throw new IllegalArgumentException(String.format("Expected the field `remote_id` to be a primitive type in the JSON string but got `%s`", jsonObj.get("remote_id").toString()));
      }
      // validate the required field `characteristic`
      SchemaBluetoothCharacteristic.validateJsonObject(jsonObj.getAsJsonObject("characteristic"));
  }

  public static class CustomTypeAdapterFactory implements TypeAdapterFactory {
    @SuppressWarnings("unchecked")
    @Override
    public <T> TypeAdapter<T> create(Gson gson, TypeToken<T> type) {
       if (!SchemaSetNotificationResponse.class.isAssignableFrom(type.getRawType())) {
         return null; // this class only serializes 'SchemaSetNotificationResponse' and its subtypes
       }
       final TypeAdapter<JsonElement> elementAdapter = gson.getAdapter(JsonElement.class);
       final TypeAdapter<SchemaSetNotificationResponse> thisAdapter
                        = gson.getDelegateAdapter(this, TypeToken.get(SchemaSetNotificationResponse.class));

       return (TypeAdapter<T>) new TypeAdapter<SchemaSetNotificationResponse>() {
           @Override
           public void write(JsonWriter out, SchemaSetNotificationResponse value) throws IOException {
             JsonObject obj = thisAdapter.toJsonTree(value).getAsJsonObject();
             elementAdapter.write(out, obj);
           }

           @Override
           public SchemaSetNotificationResponse read(JsonReader in) throws IOException {
             JsonObject jsonObj = elementAdapter.read(in).getAsJsonObject();
             validateJsonObject(jsonObj);
             return thisAdapter.fromJsonTree(jsonObj);
           }

       }.nullSafe();
    }
  }

 /**
  * Create an instance of SchemaSetNotificationResponse given an JSON string
  *
  * @param jsonString JSON string
  * @return An instance of SchemaSetNotificationResponse
  * @throws IOException if the JSON string is invalid with respect to SchemaSetNotificationResponse
  */
  public static SchemaSetNotificationResponse fromJson(String jsonString) throws IOException {
    return JSON.getGson().fromJson(jsonString, SchemaSetNotificationResponse.class);
  }

 /**
  * Convert an instance of SchemaSetNotificationResponse to an JSON string
  *
  * @return JSON string
  */
  public String toJson() {
    return JSON.getGson().toJson(this);
  }
}

