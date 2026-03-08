#include "imgui.h"
#include "implot.h"
#include "imgui_internal.h"
#include "implot_internal.h"

#ifndef ZGUI_API
#define ZGUI_API
#endif

//--------------------------------------------------------------------------------------------------
//
// ImPlot
//
//--------------------------------------------------------------------------------------------------
extern "C"
{
    ZGUI_API ImPlotContext *zguiPlot_CreateContext(void)
    {
        return ImPlot::CreateContext();
    }

    ZGUI_API void zguiPlot_DestroyContext(ImPlotContext *ctx)
    {
        ImPlot::DestroyContext(ctx);
    }

    ZGUI_API ImPlotContext *zguiPlot_GetCurrentContext(void)
    {
        return ImPlot::GetCurrentContext();
    }

    ZGUI_API ImPlotStyle zguiPlotStyle_Init(void)
    {
        return ImPlotStyle();
    }

    ZGUI_API ImPlotStyle *zguiPlot_GetStyle(void)
    {
        return &ImPlot::GetStyle();
    }

    ZGUI_API void zguiPlot_PushStyleColor4f(ImPlotCol idx, const float col[4])
    {
        ImPlot::PushStyleColor(idx, {col[0], col[1], col[2], col[3]});
    }

    ZGUI_API void zguiPlot_PushStyleColor1u(ImPlotCol idx, ImU32 col)
    {
        ImPlot::PushStyleColor(idx, col);
    }

    ZGUI_API void zguiPlot_PopStyleColor(int count)
    {
        ImPlot::PopStyleColor(count);
    }

    ZGUI_API void zguiPlot_PushStyleVar1i(ImPlotStyleVar idx, int var)
    {
        ImPlot::PushStyleVar(idx, var);
    }

    ZGUI_API void zguiPlot_PushStyleVar1f(ImPlotStyleVar idx, float var)
    {
        ImPlot::PushStyleVar(idx, var);
    }

    ZGUI_API void zguiPlot_PushStyleVar2f(ImPlotStyleVar idx, const float var[2])
    {
        ImPlot::PushStyleVar(idx, {var[0], var[1]});
    }

    ZGUI_API void zguiPlot_PopStyleVar(int count)
    {
        ImPlot::PopStyleVar(count);
    }

    ZGUI_API void zguiPlot_SetNextLineStyle(const float col[4], float weight)
    {
        ImPlot::SetNextLineStyle({col[0], col[1], col[2], col[3]}, weight);
    }

    ZGUI_API void zguiPlot_SetNextFillStyle(const float col[4], float alpha_mod)
    {
        ImPlot::SetNextFillStyle({col[0], col[1], col[2], col[3]}, alpha_mod);
    }

    ZGUI_API void zguiPlot_SetNextMarkerStyle(
        ImPlotMarker marker,
        float size,
        const float fill[4],
        float weight,
        const float outline[4])
    {
        ImPlot::SetNextMarkerStyle(marker, size, {fill[0], fill[1], fill[2], fill[3]}, weight,
            {outline[0], outline[1], outline[2], outline[3]});
    }

    ZGUI_API void zguiPlot_SetNextErrorBarStyle(const float col[4], float size, float weight)
    {
        ImPlot::SetNextErrorBarStyle({col[0], col[1], col[2], col[3]}, size, weight);
    }

    ZGUI_API void zguiPlot_SetupLegend(ImPlotLocation location, ImPlotLegendFlags flags)
    {
        ImPlot::SetupLegend(location, flags);
    }

    ZGUI_API void zguiPlot_SetupAxis(ImAxis axis, const char *label, ImPlotAxisFlags flags)
    {
        ImPlot::SetupAxis(axis, label, flags);
    }

    ZGUI_API void zguiPlot_SetupAxisLimits(ImAxis axis, double v_min, double v_max, ImPlotCond cond)
    {
        ImPlot::SetupAxisLimits(axis, v_min, v_max, cond);
    }

    ZGUI_API void zguiPlot_SetupAxisFormat(ImAxis axis, ImPlotFormatter formatter, void* user_data)
    {
        ImPlot::SetupAxisFormat(axis, formatter, user_data);
    }

    ZGUI_API void zguiPlot_SetupAxisTicks(
        ImAxis axis,
        const double *values,
        int n_ticks,
        const char *const labels[],
        bool keep_default)
    {
        ImPlot::SetupAxisTicks(axis, values, n_ticks, labels, keep_default);
    }

    ZGUI_API void zguiPlot_SetupAxisLimitsConstraints(ImAxis axis, double v_min, double v_max)
    {
        ImPlot::SetupAxisLimitsConstraints(axis, v_min, v_max);
    }

    ZGUI_API void zguiPlot_SetupAxisZoomConstraints(ImAxis axis, double z_min, double z_max)
    {
        ImPlot::SetupAxisZoomConstraints(axis, z_min, z_max);
    }

    ZGUI_API void zguiPlot_SetupFinish(void)
    {
        ImPlot::SetupFinish();
    }

    ZGUI_API void zguiPlot_SetNextAxesToFit()
    {
        ImPlot::SetNextAxesToFit();
    }

    ZGUI_API void zguiPlot_SetAxis(ImAxis axis)
    {
        ImPlot::SetAxis(axis);
    }

    ZGUI_API void zguiPlot_PixelsToPlot(float x, float y, ImAxis x_axis, ImAxis y_axis, double out[2])
    {
        const ImPlotPoint p = ImPlot::PixelsToPlot(x, y, x_axis, y_axis);
        out[0] = p.x;
        out[1] = p.y;
    }

    ZGUI_API void zguiPlot_PlotToPixels(double x, double y, ImAxis x_axis, ImAxis y_axis, float out[2])
    {
        const ImVec2 p = ImPlot::PlotToPixels(x, y, x_axis, y_axis);
        out[0] = p.x;
        out[1] = p.y;
    }

    ZGUI_API void zguiPlot_GetPlotPos(float out[2])
    {
        const ImVec2 pos = ImPlot::GetPlotPos();
        out[0] = pos.x;
        out[1] = pos.y;
    }

    ZGUI_API void zguiPlot_GetPlotSize(float out[2])
    {
        const ImVec2 size = ImPlot::GetPlotSize();
        out[0] = size.x;
        out[1] = size.y;
    }

    ZGUI_API void zguiPlot_GetPlotMousePos(ImAxis x_axis, ImAxis y_axis, double out[2])
    {
        const ImPlotPoint pos = ImPlot::GetPlotMousePos(x_axis, y_axis);
        out[0] = pos.x;
        out[1] = pos.y;
    }

    ZGUI_API bool zguiPlot_BeginPlot(const char *title_id, float width, float height, ImPlotFlags flags)
    {
        return ImPlot::BeginPlot(title_id, {width, height}, flags);
    }

    ZGUI_API void zguiPlot_EndPlot(void)
    {
        ImPlot::EndPlot();
    }

    ZGUI_API bool zguiPlot_BeginSubplots(
        const char *title_id,
        int rows,
        int cols,
        float width,
        float height,
        ImPlotSubplotFlags flags,
        float* row_ratios,
        float* col_ratios)
    {
        return ImPlot::BeginSubplots(title_id, rows, cols, {width, height}, flags, row_ratios, col_ratios);
    }

    ZGUI_API void zguiPlot_EndSubplots() {
        ImPlot::EndSubplots();
    }

    ZGUI_API void zguiPlot_PlotLineValues(
        const char *label_id,
        ImGuiDataType data_type,
        const void *values,
        int count,
        double xscale,
        double x0,
        ImPlotLineFlags flags,
        int offset,
        int stride)
    {
        if (data_type == ImGuiDataType_S8)
            ImPlot::PlotLine(label_id, (const ImS8 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_U8)
            ImPlot::PlotLine(label_id, (const ImU8 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_S16)
            ImPlot::PlotLine(label_id, (const ImS16 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_U16)
            ImPlot::PlotLine(label_id, (const ImU16 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_S32)
            ImPlot::PlotLine(label_id, (const ImS32 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_U32)
            ImPlot::PlotLine(label_id, (const ImU32 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_Float)
            ImPlot::PlotLine(label_id, (const float *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_Double)
            ImPlot::PlotLine(label_id, (const double *)values, count, xscale, x0, flags, offset, stride);
        else
            assert(false);
    }

    ZGUI_API void zguiPlot_PlotLine(
        const char *label_id,
        ImGuiDataType data_type,
        const void *xv,
        const void *yv,
        int count,
        ImPlotLineFlags flags,
        int offset,
        int stride)
    {
        if (data_type == ImGuiDataType_S8)
            ImPlot::PlotLine(label_id, (const ImS8 *)xv, (const ImS8 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_U8)
            ImPlot::PlotLine(label_id, (const ImU8 *)xv, (const ImU8 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_S16)
            ImPlot::PlotLine(label_id, (const ImS16 *)xv, (const ImS16 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_U16)
            ImPlot::PlotLine(label_id, (const ImU16 *)xv, (const ImU16 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_S32)
            ImPlot::PlotLine(label_id, (const ImS32 *)xv, (const ImS32 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_U32)
            ImPlot::PlotLine(label_id, (const ImU32 *)xv, (const ImU32 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_Float)
            ImPlot::PlotLine(label_id, (const float *)xv, (const float *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_Double)
            ImPlot::PlotLine(label_id, (const double *)xv, (const double *)yv, count, flags, offset, stride);
        else
            assert(false);
    }

    ZGUI_API void zguiPlot_PlotScatter(
        const char *label_id,
        ImGuiDataType data_type,
        const void *xv,
        const void *yv,
        int count,
        ImPlotScatterFlags flags,
        int offset,
        int stride)
    {
        if (data_type == ImGuiDataType_S8)
            ImPlot::PlotScatter(label_id, (const ImS8 *)xv, (const ImS8 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_U8)
            ImPlot::PlotScatter(label_id, (const ImU8 *)xv, (const ImU8 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_S16)
            ImPlot::PlotScatter(label_id, (const ImS16 *)xv, (const ImS16 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_U16)
            ImPlot::PlotScatter(label_id, (const ImU16 *)xv, (const ImU16 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_S32)
            ImPlot::PlotScatter(label_id, (const ImS32 *)xv, (const ImS32 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_U32)
            ImPlot::PlotScatter(label_id, (const ImU32 *)xv, (const ImU32 *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_Float)
            ImPlot::PlotScatter(label_id, (const float *)xv, (const float *)yv, count, flags, offset, stride);
        else if (data_type == ImGuiDataType_Double)
            ImPlot::PlotScatter(label_id, (const double *)xv, (const double *)yv, count, flags, offset, stride);
        else
            assert(false);
    }

    ZGUI_API void zguiPlot_PlotScatterValues(
        const char *label_id,
        ImGuiDataType data_type,
        const void *values,
        int count,
        double xscale,
        double x0,
        ImPlotScatterFlags flags,
        int offset,
        int stride)
    {
        if (data_type == ImGuiDataType_S8)
            ImPlot::PlotScatter(label_id, (const ImS8 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_U8)
            ImPlot::PlotScatter(label_id, (const ImU8 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_S16)
            ImPlot::PlotScatter(label_id, (const ImS16 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_U16)
            ImPlot::PlotScatter(label_id, (const ImU16 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_S32)
            ImPlot::PlotScatter(label_id, (const ImS32 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_U32)
            ImPlot::PlotScatter(label_id, (const ImU32 *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_Float)
            ImPlot::PlotScatter(label_id, (const float *)values, count, xscale, x0, flags, offset, stride);
        else if (data_type == ImGuiDataType_Double)
            ImPlot::PlotScatter(label_id, (const double *)values, count, xscale, x0, flags, offset, stride);
        else
            assert(false);
    }

    ZGUI_API void zguiPlot_PlotShaded(
        const char *label_id,
        ImGuiDataType data_type,
        const void *xv,
        const void *yv,
        int count,
        double yref,
        ImPlotShadedFlags flags,
        int offset,
        int stride)
    {
        if (data_type == ImGuiDataType_S8)
            ImPlot::PlotShaded(label_id, (const ImS8 *)xv, (const ImS8 *)yv, count, yref, flags, offset, stride);
        else if (data_type == ImGuiDataType_U8)
            ImPlot::PlotShaded(label_id, (const ImU8 *)xv, (const ImU8 *)yv, count, yref, flags, offset, stride);
        else if (data_type == ImGuiDataType_S16)
            ImPlot::PlotShaded(label_id, (const ImS16 *)xv, (const ImS16 *)yv, count, yref, flags, offset, stride);
        else if (data_type == ImGuiDataType_U16)
            ImPlot::PlotShaded(label_id, (const ImU16 *)xv, (const ImU16 *)yv, count, yref, flags, offset, stride);
        else if (data_type == ImGuiDataType_S32)
            ImPlot::PlotShaded(label_id, (const ImS32 *)xv, (const ImS32 *)yv, count, yref, flags, offset, stride);
        else if (data_type == ImGuiDataType_U32)
            ImPlot::PlotShaded(label_id, (const ImU32 *)xv, (const ImU32 *)yv, count, yref, flags, offset, stride);
        else if (data_type == ImGuiDataType_Float)
            ImPlot::PlotShaded(label_id, (const float *)xv, (const float *)yv, count, yref, flags, offset, stride);
        else if (data_type == ImGuiDataType_Double)
            ImPlot::PlotShaded(label_id, (const double *)xv, (const double *)yv, count, yref, flags, offset, stride);
        else
            assert(false);
    }
    ZGUI_API void zguiPlot_PlotBars(
        const char *label_id,
        ImGuiDataType data_type,
        const void *xv,
        const void *yv,
        int count,
        double bar_size,
        ImPlotBarsFlags flags,
        int offset,
        int stride)
    {
        if (data_type == ImGuiDataType_S8)
            ImPlot::PlotBars(label_id, (const ImS8 *)xv, (const ImS8 *)yv, count, bar_size, flags, offset, stride);
        else if (data_type == ImGuiDataType_U8)
            ImPlot::PlotBars(label_id, (const ImU8 *)xv, (const ImU8 *)yv, count, bar_size, flags, offset, stride);
        else if (data_type == ImGuiDataType_S16)
            ImPlot::PlotBars(label_id, (const ImS16 *)xv, (const ImS16 *)yv, count, bar_size, flags, offset, stride);
        else if (data_type == ImGuiDataType_U16)
            ImPlot::PlotBars(label_id, (const ImU16 *)xv, (const ImU16 *)yv, count, bar_size, flags, offset, stride);
        else if (data_type == ImGuiDataType_S32)
            ImPlot::PlotBars(label_id, (const ImS32 *)xv, (const ImS32 *)yv, count, bar_size, flags, offset, stride);
        else if (data_type == ImGuiDataType_U32)
            ImPlot::PlotBars(label_id, (const ImU32 *)xv, (const ImU32 *)yv, count, bar_size, flags, offset, stride);
        else if (data_type == ImGuiDataType_Float)
            ImPlot::PlotBars(label_id, (const float *)xv, (const float *)yv, count, bar_size, flags, offset, stride);
        else if (data_type == ImGuiDataType_Double)
            ImPlot::PlotBars(label_id, (const double *)xv, (const double *)yv, count, bar_size, flags, offset, stride);
        else
            assert(false);
    }

    ZGUI_API void zguiPlot_PlotBarsValues(
        const char *label_id,
        ImGuiDataType data_type,
        const void *values,
        int count,
        double bar_size,
        double shift,
        ImPlotBarsFlags flags,
        int offset,
        int stride)
    {
        if (data_type == ImGuiDataType_S8)
            ImPlot::PlotBars(label_id, (const ImS8 *)values, count, bar_size, shift, flags, offset, stride);
        else if (data_type == ImGuiDataType_U8)
            ImPlot::PlotBars(label_id, (const ImU8 *)values, count, bar_size, shift, flags, offset, stride);
        else if (data_type == ImGuiDataType_S16)
            ImPlot::PlotBars(label_id, (const ImS16 *)values, count, bar_size, shift, flags, offset, stride);
        else if (data_type == ImGuiDataType_U16)
            ImPlot::PlotBars(label_id, (const ImU16 *)values, count, bar_size, shift, flags, offset, stride);
        else if (data_type == ImGuiDataType_S32)
            ImPlot::PlotBars(label_id, (const ImS32 *)values, count, bar_size, shift, flags, offset, stride);
        else if (data_type == ImGuiDataType_U32)
            ImPlot::PlotBars(label_id, (const ImU32 *)values, count, bar_size, shift, flags, offset, stride);
        else if (data_type == ImGuiDataType_Float)
            ImPlot::PlotBars(label_id, (const float *)values, count, bar_size, shift, flags, offset, stride);
        else if (data_type == ImGuiDataType_Double)
            ImPlot::PlotBars(label_id, (const double *)values, count, bar_size, shift, flags, offset, stride);
        else
            assert(false);
    }

    ZGUI_API bool zguiPlot_IsPlotHovered()
    {
        return ImPlot::IsPlotHovered();
    }
    ZGUI_API void zguiPlot_GetLastItemColor(float color[4])
    {
        const ImVec4 col = ImPlot::GetLastItemColor();
        color[0] = col.x;
        color[1] = col.y;
        color[2] = col.z;
        color[3] = col.w;
    }

    ZGUI_API ImDrawList* zguiPlot_GetPlotDrawList()
    {
        return ImPlot::GetPlotDrawList();
    }

    ZGUI_API void zguiPlot_PushPlotClipRect(float expand)
    {
        ImPlot::PushPlotClipRect(expand);
    }

    ZGUI_API void zguiPlot_PopPlotClipRect()
    {
        ImPlot::PopPlotClipRect();
    }

    ZGUI_API void zguiPlot_ShowDemoWindow(bool *p_open)
    {
        ImPlot::ShowDemoWindow(p_open);
    }

    ZGUI_API bool zguiPlot_DragPoint(
        int id,
        double *x,
        double *y,
        float col[4],
        float size,
        ImPlotDragToolFlags flags)
    {
        return ImPlot::DragPoint(
            id,
            x,
            y,
            (*(const ImVec4 *)&(col[0])),
            size,
            flags);
    }

    ZGUI_API void zguiPlot_TagX(double x, float col[4], bool round)
    {
        ImPlot::TagX(x, (*(const ImVec4 *)&(col[0])), round);
    }

    ZGUI_API void zguiPlot_TagXText(double x, float col[4], const char *fmt, ...)
    {
        va_list args;
        va_start(args, fmt);
        ImPlot::TagXV(x, (*(const ImVec4 *)&(col[0])), fmt, args);
        va_end(args);
    }

    ZGUI_API void zguiPlot_TagY(double y, float col[4], bool round)
    {
        ImPlot::TagY(y, (*(const ImVec4 *)&(col[0])), round);
    }

    ZGUI_API void zguiPlot_TagYText(double y, float col[4], const char *fmt, ...)
    {
        va_list args;
        va_start(args, fmt);
        ImPlot::TagYV(y, (*(const ImVec4 *)&(col[0])), fmt, args);
        va_end(args);
    }

    ZGUI_API void zguiPlot_PlotText(
        const char *text,
        double x, double y,
        const float pix_offset[2],
        ImPlotTextFlags flags = 0)
    {
        const ImVec2 p(pix_offset[0], pix_offset[1]);
        ImPlot::PlotText(text, x, y, p, flags);
    }

    ZGUI_API bool zguiPlot_BeginItem(
        const char *label_id,
        ImPlotItemFlags flags,
        ImPlotCol recolor_from)
    {
        return ImPlot::BeginItem(label_id, flags, recolor_from);
    }

    ZGUI_API void zguiPlot_EndItem()
    {
        ImPlot::EndItem();
    }

    ZGUI_API void zguiPlot_FitPointX(double x)
    {
        ImPlot::FitPointX(x);
    }

    ZGUI_API void zguiPlot_FitPointY(double y)
    {
        ImPlot::FitPointY(y);
    }

    ZGUI_API void zguiPlot_FitPoint(double x, double y)
    {
        ImPlot::FitPoint({x, y});
    }

} /* extern "C" */
